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

    def start 
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

      sendRequest(configureVideoEncoder(airEncoderID, {:fps => airEncoderFPS, :bitrate => 3000}))
      sendRequest(configureVideoEncoder(previewEncoderID, {:fps => airEncoderFPS/2, :bitrate => 3000}))
      sendRequest(configureResampler(airResamplerEncoderID, 0, 0, {:pixelFormat => 2}))
      sendRequest(configureResampler(previewResamplerEncoderID, 0, 0, {:pixelFormat => 2, :discartPeriod => 2}))

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

      # #OUTPUT

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

    def addRTPSession(mixerChannel, sourceIP, sourceType, port, medium, codec, bandwidth, timeStampFrequency, channels = 0)
      
      #TODO first check if sourceIP already exists inside audio or video list, then give available cport
      #then check decklink (to check inside audio if embedded or analog)
      
      case sourceType
      when "ultragrid"
        if uv_check_and_tx(sourceIP, port, 6054)
          receiver = @db.getFilterByType('receiver')

          @conn.addRTPSession(receiver["id"], port, medium, codec, bandwidth, timeStampFrequency, channels)
          #TODO manage response
          sendRequest(@conn.addRTPSession(receiver["id"], port, medium, codec, bandwidth, timeStampFrequency, channels))

          puts "error setting control port" if !set_controlport(sourceIP, 6054)
            
          orig_chParams = getUltraGridParams(sourceIP)
            
          chParams = {
            :ip => sourceIP.to_s,
            :sourceType => sourceType,
            :size => !orig_chParams.empty? ? orig_chParams[:o_size]: "",
            :fps => !orig_chParams.empty? ? orig_chParams[:o_fps]: "",
            :br => !orig_chParams.empty? ? orig_chParams[:o_br]: "",
            :vbcc => false
          }  
          
          puts "\n\nADDING NEW ULTRAGRID CHANNEL PARAMS TO DB:"  
          puts chParams
          puts "\n\n"  

          @db.addInputChannelParams(mixerChannel, chParams) #TODO manage response
            
          if medium == 'audio'
            #TODO ADD AUDIO... 
          elsif medium == 'video'
            @db.addVideoChannelPort(mixerChannel, port)
            createVideoInputPaths(port)
            applyPreviewGrid
          end

          updateDataBase
        end
      when "other"
        receiver = @db.getFilterByType('receiver')

        #TODO manage response
        sendRequest(@conn.addRTPSession(receiver["id"], port, medium, codec, bandwidth, timeStampFrequency, channels))

        # chParams = {
        #   :ip => sourceIP.to_s,
        #   :sourceType => sourceType,
        #   :size => "",
        #   :fps => "",
        #   :br => "",
        #   :vbcc => false
        # }  
        
        #@db.addInputChannelParams(mixerChannel, chParams) #TODO manage response  
          
        if medium == 'audio'
			    createAudioInputPath(port)
        elsif medium == 'video'
          @db.addVideoChannelPort(mixerChannel, port)
          createVideoInputPaths(port)
          applyPreviewGrid
        end

        updateDataBase
        
      else
        puts "Please, select between ultragrid or other type of sources..."
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
        unless processorLimit != 0 and processorLimit >= w["processors"].size
          sendRequest(addFiltersToWorker(w["id"], [filterId]))
          @db.addProcessorToWorker(w["id"], filterId, filterType)
          return w["id"]
        end
      end

      newWorker = Random.rand(@randomSize)
      sendRequest(addWorker(newWorker, workerType))
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

      intervals = (time/@videoFadeInterval)
      deltaOp = 1.0/intervals
      
      mixer["channels"].each do |ch|
        if ch["layer"] >= 7
          ch["layer"] = 6
          appendEvent(updateVideoChannel(@airMixerID, ch))
        end
      end

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
      slave = assignWorker(previewResamplerID, 'videoResampler', 'bestEffortSlave', {:processorLimit => 2})

      sendRequest(addSlavesToWorker(master, [slave]))
    end

    def createAudioInputPath(port)
      receiver = @db.getFilterByType('receiver')
      
      decoderID = Random.rand(@randomSize)
      decoderPathID = Random.rand(@randomSize)

      createFilter(decoderID, 'audioDecoder')
      createPath(decoderPathID, receiver["id"], @audioMixer, [decoderID], {:orgWriterId => port, :dstReaderId => port})

      assignWorker(decoderID, 'audioDecoder', 'bestEffortMaster')
    end

    def updateInputChannelSize(channelID, size)
      chParams = @db.getInputChannelParams(channelID)
      config_hash = set_size(chParams["ip"], size)
      if config_hash.empty?
        #TODO manage errors
      else
        updateInputChannelParams(channelID, config_hash)
      end
    end
    
    def updateInputChannelVBCC(channelID, mode)
      chParams = @db.getInputChannelParams(channelID)
      config_hash = set_vbcc(chParams["ip"], mode)
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
