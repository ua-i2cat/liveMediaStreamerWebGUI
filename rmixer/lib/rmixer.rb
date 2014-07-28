#
#  RUBYMIXER - A management ruby interface for MIXER 
#  Copyright (C) 2013  Fundació i2CAT, Internet i Innovació digital a Catalunya
#
#  This file is part of thin RUBYMIXER.
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#  Authors:  Marc Palau <marc.palau@i2cat.net>,
#            Ignacio Contreras <ignacio.contreras@i2cat.net>
#   

require "rmixer/version"
require "connector"
require "append"
require "grids"
require "ultragrid"
require "mongodb"


module RMixer

  # Generic error to be thrown when an error is returned by the remote
  # *Mixer* instance
  class MixerError < StandardError
  end

  # Proxy class that delegates most of it functions to a RMixer::Connector
  # instance while adding exception and convenience methods.
  class Mixer

    def initialize(host, port)
      @conn = RMixer::Connector.new(host, port)
      @db = RMixer::MongoMngr.new
      @uv = RMixer::UltraGridRC.new
      @started = false
      @randomSize = 2**16
      @videoFadeInterval = 50 #ms

      loadGrids
    end

    def loadGrids
      grids = []

      grids << calcRegularGrid(2, 2)
      grids << calcRegularGrid(3, 3)
      grids << calcRegularGrid(4, 4)
      grids << calcPictureInPicture
      grids << calcPreviewGrid

      @db.loadGrids(grids)
    end

    def isStarted
      @started
    end

    def resetScenario
      sendRequest(reset)

    end

    def start
      resetScenario

      @airMixerID = Random.rand(@randomSize)
      @previewMixerID = Random.rand(@randomSize)
      airEncoderID = Random.rand(@randomSize)
      previewEncoderID = Random.rand(@randomSize)
      airResamplerEncoderID = Random.rand(@randomSize)
      previewResamplerEncoderID = Random.rand(@randomSize)
      airOutputPathID = Random.rand(@randomSize)
      previewOutputPathID = Random.rand(@randomSize)

      createFilter(@airMixerID, 'videoMixer')
      createFilter(@previewMixerID, 'videoMixer')
      createFilter(airEncoderID, 'videoEncoder')
      createFilter(previewEncoderID, 'videoEncoder')
      createFilter(airResamplerEncoderID, 'videoResampler')
      createFilter(previewResamplerEncoderID, 'videoResampler')

      txId = @db.getFilterByType('transmitter')["id"]

      createPath(airOutputPathID, @airMixerID, txId, [airResamplerEncoderID, airEncoderID])
      createPath(previewOutputPathID, @previewMixerID, txId, [previewResamplerEncoderID, previewEncoderID])

      airPath = @db.getPath(airOutputPathID)
      previewPath = @db.getPath(previewOutputPathID)

      airEncoderFPS = 24

      assignWorker(@airMixerID, 'videoMixer', 'bestEffortMaster')
      assignWorker(@previewMixerID, 'videoMixer', 'bestEffortMaster')
      assignWorker(airEncoderID, 'videoEncoder', 'cFramerateMaster', {:fps => airEncoderFPS})
      assignWorker(previewEncoderID, 'videoEncoder', 'cFramerateMaster', {:fps => airEncoderFPS/2})
      assignWorker(airResamplerEncoderID, 'videoResampler', 'bestEffortMaster')
      assignWorker(previewResamplerEncoderID, 'videoResampler', 'bestEffortMaster')

      sendRequest(configureVideoEncoder(airEncoderID, {:bitrate => 3000}))
      sendRequest(configureVideoEncoder(previewEncoderID, {:bitrate => 3000}))
      sendRequest(configureResampler(airResamplerEncoderID, 0, 0, {:pixelFormat => 2}))
      sendRequest(configureResampler(previewResamplerEncoderID, 0, 0, {:pixelFormat => 2}))

      @audioMixer = Random.rand(@randomSize)
      audioEncoder =  Random.rand(@randomSize)
      audioPathID = Random.rand(@randomSize)
      audioMixerWorker = Random.rand(@randomSize)
      audioEncoderWorker = Random.rand(@randomSize)

      createFilter(@audioMixer, 'audioMixer')
      createFilter(audioEncoder, 'audioEncoder')

      createPath(audioPathID, @audioMixer, txId, [audioEncoder])

      audioPath = @db.getPath(audioPathID)

      assignWorker(@audioMixer, 'audioMixer', 'bestEffortMaster')
      assignWorker(audioEncoder, 'audioEncoder', 'bestEffortMaster')

      #OUTPUT

      sendRequest(@conn.addOutputSession(txId, [airPath["destinationReader"], audioPath["destinationReader"]], 'air'))
      sendRequest(@conn.addOutputSession(txId, [previewPath["destinationReader"]], 'preview'))
      @started = true

      updateDataBase
    end

    def updateDataBase
      stateHash = sendRequest(getState)
      @db.update(stateHash)
    end

    def getVideoMixerState(grid = '2x2')
      @db.getVideoMixerState(@airMixerID, grid)
    end

    def createFilter(id, type, role = 'default')
      begin 
        response = sendRequest(@conn.createFilter(id, type))
        raise MixerError, response[:error] if response[:error]
      rescue
        return response
      end

      updateDataBase
    end

    def createPath(id, orgFilterId, dstFilterId, midFiltersIds, options = {})
      orgWriterId = (options[:orgWriterId].to_i != 0) ? options[:orgWriterId].to_i : -1
      dstReaderId = (options[:dstReaderId].to_i != 0) ? options[:dstReaderId].to_i : -1
      sharedQueue = (options[:sharedQueue] != nil) ? options[:sharedQueue] : false

      begin 
        response = sendRequest(@conn.createPath(id, orgFilterId, dstFilterId, orgWriterId, dstReaderId, midFiltersIds, sharedQueue))
        raise MixerError, response[:error] if response[:error]
      rescue
        return response
      end

      updateDataBase
    end

    def updateChannelVolume(id, volume)
      @db.updateChannelVolume
    end

    def configEncoder(encoderID, codec, sampleRate, channels)
      encoder = @db.getFilter(encoderID)

      if encoder["codec"] == codec
        configAudioEncoder(encoderID, sampleRate, channels)
      else
        reconfigAudioEncoder(encoderID, codec, sampleRate, channels)
      end
    end

    def addRTSPSession(mixerChannel, progName, uri)
      receiver = @db.getFilterByType('receiver')
      id = uri.split('/').last
      sendRequest(@conn.addRTSPSession(receiver["id"], progName, uri, id))

      session = {}

      begin
        sleep(1.0/5.0) #sleep 200 ms
        stateHash = sendRequest(getState)

        stateHash[:filters].each do |f|
          if f[:type] == 'receiver' and f[:sessions]
            f[:sessions].each do |s|
              if s[:id] == id and s[:subsessions]
                session = s
              end
            end
          end
        end
      end while session.empty?

      chCount = 0
      session[:subsessions].each do |s|
        if s[:medium] == 'audio'
          createAudioInputPath(s[:port])
        elsif s[:medium] == 'video'
          @db.addVideoChannelPort(mixerChannel + chCount, s[:port])
          createVideoInputPaths(s[:port])
          applyPreviewGrid
          chCount += 1
        end
      end
    end
    
    def addRTPSession(medium, params, bandwidth, timeStampFrequency)
      #TODO CHECK IF PORT ALREADY OCCUPYED!!!
      #TODO first check if sourceIP already exists inside audio or video list, then give available cport
      #then check decklink (to check inside audio if embedded or analog)
      port = params[:port].to_i
      return if port == 0

      sourceType = params[:sourceType]
      sourceIP = params[:sourceIP]
      codec = params[:codec]
      
      case medium
      when "audio"
        mixerChannel = 0
        channels = params[:channels].to_i
        timeStampFrequency = params[:sampleRate].to_i
        case sourceType
          when "ultragrid"
            if @uv.uv_check_and_tx(sourceIP, port, medium, timeStampFrequency, channels)
              receiver = @db.getFilterByType('receiver')
              #TODO ADD OPUS SUPPORT IN ULTRAGRID, NOW ONLY PCMU
              #TODO manage response
              sendRequest(@conn.addRTPSession(receiver["id"], port, medium, "pcmu", bandwidth, timeStampFrequency, channels))

              puts "error setting control port" if !@uv.set_controlport(sourceIP)
              chParams = {:ip => sourceIP.to_s,
                :medium => medium,
                :sourceType => sourceType
              }
              @db.addInputChannelParams(mixerChannel, chParams) #TODO manage response
              createAudioInputPath(port)
              updateDataBase
            end
          when "other"
            receiver = @db.getFilterByType('receiver')
            #TODO manage response
            sendRequest(@conn.addRTPSession(receiver["id"], port, medium, codec, bandwidth, timeStampFrequency, channels))
            chParams = {:ip => sourceIP.to_s,
              :medium => medium,
              :sourceType => sourceType 
            }
            @db.addInputChannelParams(mixerChannel, chParams) #TODO manage response
            createAudioInputPath(port)
            updateDataBase
          else
            puts "Please, select between ultragrid or other type of sources..."
          end
          
      when "video"
        mixerChannel = params[:channel].to_i
        
        case sourceType
        when "ultragrid"
          if @uv.uv_check_and_tx(sourceIP, port, medium, 0, 0)
            receiver = @db.getFilterByType('receiver')

            #@conn.addRTPSession(receiver["id"], port, medium, codec, bandwidth, timeStampFrequency, channels)
            #TODO manage response
            sendRequest(@conn.addRTPSession(receiver["id"], port, medium, codec, bandwidth, timeStampFrequency, channels))

            puts "error setting control port" if !@uv.set_controlport(sourceIP)

            orig_chParams = @uv.getUltraGridParams(sourceIP)
            if !orig_chParams.empty?

              puts "UltraGrid has crashed... check source!"
              orig_chParams[:o_size] = "1920x1080"
              orig_chParams[:o_fps] = 25
              orig_chParams[:o_br] = 12200
              chParams = {
                :ip => sourceIP.to_s,
                :sourceType => sourceType,
                :size_val => !orig_chParams.empty? ? orig_chParams[:o_size]: "",
                :fps_val => !orig_chParams.empty? ? orig_chParams[:o_fps].to_f.round(2): "",
                :br_val => !orig_chParams.empty? ? orig_chParams[:o_br].to_f.round(2): "",
                :size => "H",
                :fps => "H",
                :br => "H",
                :vbcc => false
              }

              puts "\n\nADDING NEW ULTRAGRID CHANNEL PARAMS TO DB:"
              puts chParams
              puts "\n\n"
              
              if orig_chParams[:uv_params].include?"embedded"
                #ADD AUDIO EMBEDDED
                receiver = @db.getFilterByType('receiver')
                #TODO manage response
                sendRequest(@conn.addRTPSession(receiver["id"], port+2, "audio", "pcmu", 5000, 48000, 2))
                chParams = {:ip => sourceIP.to_s,
                  :medium => "audio",
                  :sourceType => "ultragrid" 
                }
                @db.addInputChannelParams(0, chParams) #TODO manage response
                createAudioInputPath(port)
                updateDataBase
              end
              
              @db.addInputChannelParams(mixerChannel, chParams) #TODO manage response

              @db.addVideoChannelPort(mixerChannel, port)
              createVideoInputPaths(port)
              applyPreviewGrid

              updateDataBase
              
            end
          end
        when "other"
          receiver = @db.getFilterByType('receiver')

          #TODO manage response
          sendRequest(@conn.addRTPSession(receiver["id"], port, medium, codec, bandwidth, timeStampFrequency, channels))

          chParams = {
            :ip => sourceIP.to_s,
            :sourceType => sourceType,
            :size => "",
            :fps => "",
            :br => "",
            :size_val => "",
            :fps_val => "",
            :br_val => "",
            :vbcc => false
          }

          puts "\n\nADDING NEW CHANNEL PARAMS TO DB:"
          puts chParams
          puts "\n\n"

          @db.addInputChannelParams(mixerChannel, chParams) #TODO manage response

          @db.addVideoChannelPort(mixerChannel, port)
          createVideoInputPaths(port)
          applyPreviewGrid

          updateDataBase

          else
            puts "Please, select between ultragrid or other type of sources..."
          end
      else
        puts "Error, no medium type..."
      end
    end
    
    def rmRTPSession(mixerChannel, port, medium, codec, bandwidth, timeStampFrequency, channels = 0)
#      receiver = @db.getFilterByType('receiver')
#      @conn.addRTPSession(receiver["id"], port, medium, codec, bandwidth, timeStampFrequency, channels)
#
#      if medium == 'audio'
#      elsif medium == 'video'
#        @db.addVideoChannelPort(mixerChannel, port)
#        createInputPaths(port)
#        applyPreviewGrid
#      end
      
    end

    def addOutputSession(mixerID, sessionName)
      path = @db.getOutputPathFromFilter(mixerID)
      readers = []
      readers << path["destinationReader"]
      sendRequest(@conn.addOutputSession(path["destinationFilter"], readers, sessionName))

      updateDataBase
    end

    def assignWorker(filterId, filterType, workerType, options = {})
      processorLimit = (options[:processorLimit]) ? options[:processorLimit] : 0
      fps = (options[:fps]) ? options[:fps] : 24

      @db.getWorkerByType(workerType, filterType, fps).each do |w|
        if processorLimit == 0 || processorLimit > w["processors"].size
          sendRequest(addFiltersToWorker(w["id"], [filterId]))
          @db.addProcessorToWorker(w["id"], filterId, filterType)
          return w["id"]
        end
      end

      newWorker = Random.rand(@randomSize)
      sendRequest(addWorker(newWorker, workerType, fps))
      @db.addWorker(newWorker, workerType, filterType, fps)
      sendRequest(addFiltersToWorker(newWorker, [filterId]))
      @db.addProcessorToWorker(newWorker, filterId, filterType)
      return newWorker
    end

    # Video methods
    def applyPreviewGrid
      grid = @db.getGrid('preview')
      mixer = getFilter(@previewMixerID)

      grid["positions"].each do |p|
        mixerChannelId = @db.getVideoChannelPort(p["id"])

        unless mixerChannelId == 0
          path = getPathByDestination(@previewMixerID, mixerChannelId)
          resamplerID = path["filters"].first

          width = p["width"]*mixer["width"]
          height = p["height"]*mixer["height"]

          appendEvent(configureResampler(resamplerID, width, height))

          appendEvent(
            setPositionSize(
              @previewMixerID, 
              mixerChannelId,
              p["width"],
              p["height"],
              p["x"],
              p["y"],
              p["layer"], 
              p["opacity"]
            )
          )
        end
      end

      sendRequest

      updateDataBase
    end

    def applyGrid(gridID, positions)
      grid = @db.getGrid(gridID)

      updateGrid(grid, positions)
      doApplyGrid(grid)

      @db.updateGrid(grid)
    end

    def updateGrid(grid, positions)
      grid["positions"].each do |oldP|
        positions.each do |newP|
          if newP[:pos] == oldP["id"]
            oldP["channel"] = newP[:ch]
            break;
          end
        end
      end

    end

    def doApplyGrid(grid)
      mixer = getFilter(@airMixerID)

      mixer["channels"].each do |ch|
        position = {}

        grid["positions"].each do |p|
          if ch["id"] == @db.getVideoChannelPort(p["channel"])
            position = p
          end
        end

        if position.empty?
          ch["enabled"] = false
          appendEvent(updateVideoChannel(@airMixerID, ch))
        else
          ch["width"] = position["width"]
          ch["height"] = position["height"]
          ch["x"] = position["x"]
          ch["y"] = position["y"]
          ch["layer"] = position["layer"]
          ch["opacity"] = position["opacity"]
          ch["enabled"] = true 

          appendEvent(updateVideoChannel(@airMixerID, ch))

          path = getPathByDestination(@airMixerID, ch["id"])
          resamplerID = path["filters"].first

          width = ch["width"]*mixer["width"]
          height = ch["height"]*mixer["height"]

          appendEvent(configureResampler(resamplerID, width, height))

        end
      end

      sendRequest

      updateFilter(mixer)
    end

    def commute(channel)
      @db.resetGrids
      mixer = getFilter(@airMixerID)
      port = @db.getVideoChannelPort(channel)

      mixer["channels"].each do |ch|
        if ch["id"] == port
          ch["width"] = 1
          ch["height"] = 1
          ch["x"] = 0
          ch["y"] = 0
          ch["layer"] = 1
          ch["opacity"] = 1.0
          ch["enabled"] = true
          
          appendEvent(updateVideoChannel(@airMixerID, ch))

          path = getPathByDestination(@airMixerID, ch["id"])
          resamplerID = path["filters"].first

          width = ch["width"]*mixer["width"]
          height = ch["height"]*mixer["height"]

          appendEvent(configureResampler(resamplerID, width, height))
        else
          ch["enabled"] = false 
          
          appendEvent(updateVideoChannel(@airMixerID, ch))
        end
      end

      sendRequest

      updateFilter(mixer)
    end

    def fade(channel, time)
      mixer = getFilter(@airMixerID)
      port = @db.getVideoChannelPort(channel)
      path = getPathByDestination(@airMixerID, port)
      resamplerID = path["filters"].first

      intervals = (time/@videoFadeInterval)
      deltaOp = 1.0/intervals
      
      mixer["channels"].each do |ch|
        if ch["layer"] >= 7
          ch["layer"] = 6
          appendEvent(updateVideoChannel(@airMixerID, ch))
        end
      end

      appendEvent(configureResampler(resamplerID, mixer["width"], mixer["height"]))

      intervals.times do |d|
        appendEvent(setPositionSize(@airMixerID, port, 1, 1, 0, 0, 7, d*deltaOp), d*@videoFadeInterval)
      end

      mixer["channels"].each do |ch|
        if ch["id"] == port
          ch["width"] = 1
          ch["height"] = 1
          ch["x"] = 0
          ch["y"] = 0
          ch["layer"] = 7
          ch["opacity"] = 1.0
          ch["enabled"] = true

          appendEvent(updateVideoChannel(@airMixerID, ch), intervals*@videoFadeInterval)

        else 
          ch["enabled"] = false

          appendEvent(updateVideoChannel(@airMixerID, ch), intervals*@videoFadeInterval)
        end
      end

      sendRequest

      updateFilter(mixer)

    end

    #NETWORKED PRODUCTION

    def createVideoInputPaths(port)
      receiver = @db.getFilterByType('receiver')

      decoderID = Random.rand(@randomSize)
      airResamplerID = Random.rand(@randomSize)
      previewResamplerID = Random.rand(@randomSize)
      decoderPathID = Random.rand(@randomSize)
      airPathID = Random.rand(@randomSize)
      previewPathID = Random.rand(@randomSize)

      createFilter(decoderID, 'videoDecoder')
      createFilter(airResamplerID, 'videoResampler')
      createFilter(previewResamplerID, 'videoResampler')

      createPath(decoderPathID, receiver["id"], decoderID, [], {:orgWriterId => port})
      createPath(airPathID, decoderID, @airMixerID, [airResamplerID], {:dstReaderId => port})
      createPath(previewPathID, decoderID, @previewMixerID, [previewResamplerID], {:dstReaderId => port, :sharedQueue => true})

      assignWorker(decoderID, 'videoDecoder', 'bestEffortMaster', {:processorLimit => 2})
      master = assignWorker(airResamplerID, 'videoResampler', 'bestEffortMaster', {:processorLimit => 2})
      slave = assignWorker(previewResamplerID, 'videoResampler', 'slave', {:processorLimit => 2})
     
      sendRequest(addSlavesToWorker(master, [slave]))
      sendRequest(configureResampler(previewResamplerID, 0, 0, {:discartPeriod => 2}))
    end

    def createAudioInputPath(port)
      receiver = @db.getFilterByType('receiver')
      
      decoderID = Random.rand(@randomSize)
      decoderPathID = Random.rand(@randomSize)

      createFilter(decoderID, 'audioDecoder')
      createPath(decoderPathID, receiver["id"], @audioMixer, [decoderID], {:orgWriterId => port, :dstReaderId => port})

      assignWorker(decoderID, 'audioDecoder', 'bestEffortMaster')
    end

    def updateInputChannelVBCC(channelID, mode)
      chParams = @db.getInputChannelParams(channelID)
      config_hash = @uv.set_vbcc(chParams["ip"], mode)
      if config_hash.empty?
        #TODO manage errors
      else
        updateInputChannelParams(channelID, config_hash)
      end
    end
    
    def updateInputChannelSize(channelID, size)
      chParams = @db.getInputChannelParams(channelID)
      config_hash = @uv.set_size(chParams["ip"], size)
      if config_hash.empty?
        #TODO manage errors
      else
        updateInputChannelParams(channelID, config_hash)
      end
    end
    
    def updateInputChannelFPS(channelID, fps)
      chParams = @db.getInputChannelParams(channelID)
      config_hash = @uv.set_fps(chParams["ip"], fps)
      if config_hash.empty?
        #TODO manage errors
      else
        updateInputChannelParams(channelID, config_hash)
      end
    end
    
    def updateInputChannelBitRate(channelID, br)
      chParams = @db.getInputChannelParams(channelID)
      config_hash = @uv.set_br(chParams["ip"], br)
      if config_hash.empty?
        #TODO manage errors
      else
        updateInputChannelParams(channelID, config_hash)
      end
    end

    private :doApplyGrid, :updateGrid

    def method_missing(name, *args, &block)
      if @conn.respond_to?(name)
        begin
          response = @conn.send(name, *args, &block)
        rescue JSON::ParserError, Errno::ECONNREFUSED => e
          raise MixerError, e.message
        end
        raise MixerError, response[:error] if response[:error]
        #return nil if response.include?(:error) && response.size == 1
        return response
      elsif @db.respond_to?(name)
        begin
          response = @db.send(name, *args, &block)
        rescue JSON::ParserError, Errno::ECONNREFUSED => e
          raise MixerError, e.message
        end
        raise MixerError, response[:error] if response[:error]
        #return nil if response.include?(:error) && response.size == 1
        return response
      else
        super
      end
    end

  end

end
