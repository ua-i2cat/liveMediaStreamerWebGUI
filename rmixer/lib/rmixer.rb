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
#            Gerard Castillo <gerard.castillo@i2cat.net>
#

require "rmixer/version"
require "connector"
require "grids"
require "mongodb"
require 'mkmf'
require 'open3'
require 'thread'

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
      @lmsStarted = false
      @lmsThread = nil
      @lmspid = nil
      @randomSize = 2**16
      @videoFadeInterval = 50 #ms
    end

    def check_livemediastreamer_installation
      if !(find_executable 'livemediastreamer').nil?
        return true
      else
        return false
      end
    end

    def check_livemediastreamer_process
      if `ps aux | grep livemediastreamer | grep --invert grep` != ""
        found = `ps aux | grep livemediastreamer | grep --invert grep`
        tmpPid = `ps aux | grep livemediastreamer | grep --invert grep |awk '{ print $2 }'`
        Process.kill("TERM", tmpPid.to_i)
      end
    end

    def run_livemediastreamer
      return if isStarted #force only one process
      cmd = "livemediastreamer 7777"
      #run thread livemediastreamer (parsing std and output stdout and stderr)
      @lmsThread = Thread.new do   # Calling a class method new
        begin
          Open3.popen2e(cmd) do |stdin, stdout_err, wait_thr|
            @lmspid = wait_thr[:pid]

            while line = stdout_err.gets
              puts "--> livemediastreamer output:  #{line}"
            end

            exit_status = wait_thr.value
            if exit_status.success?
              puts "#{cmd} running!"
              @lmsStarted = true
            else
              puts "#{cmd} failed!!!"
              @lmsStarted = false
            end
          end
        rescue SignalException => e
          raise e
        rescue Exception => e
          puts "#{cmd} failed!!!"
          @lmsStarted = false
        end
        @lmsStarted = false
      end
      @lmsStarted = true
    end

    def stop
      if @lmsStarted
        sendRequest(@conn.stop)
        @db.clear
        stop_livemediastreamer ? @started = false : @started = true
      else
        puts "livemediastreamer not running...ambiguous situation...!"
      end
    end

    def stop_livemediastreamer
      begin
        puts "Stopping livemediastreamer"
        Process.kill("TERM", @lmspid)
        Thread.kill(@lmsThread)
      rescue SignalException => e
        raise e
      rescue Exception => e
        puts "No succes on exiting livemediastreamer...!"
        @lmsStarted = true
        return false
      end
      puts "livemediastreamer exit success"
      @lmsStarted = false
      return true
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
      @db.clear
    end

    def start
     if @lmsStarted
       raise MixerError, "Live Media Streamer is still running"
     end

     if !check_livemediastreamer_installation
       raise MixerError, "Live Media Streamer is not installed"
     end

     check_livemediastreamer_process
     run_livemediastreamer
     sleep(1)

      if !@lmsStarted
       raise MixerError, "Error starting Live Media Streamer"
     end

      resetScenario
      loadGrids

      @airMixerID = Random.rand(@randomSize)
      @previewMixerID = Random.rand(@randomSize)
      airEncoderID = Random.rand(@randomSize)
      previewEncoderID = Random.rand(@randomSize)
      airResamplerEncoderID = Random.rand(@randomSize)
      previewResamplerEncoderID = Random.rand(@randomSize)
      airOutputPathID = Random.rand(@randomSize)
      previewOutputPathID = Random.rand(@randomSize)
      transmitterID = Random.rand(@randomSize)
      receiverID = Random.rand(@randomSize)
      @audioMixer = Random.rand(@randomSize)
      audioEncoder =  Random.rand(@randomSize)
      audioPathID = Random.rand(@randomSize)

      events = []
      events << @conn.createFilter(receiverID, 'receiver', 'network')
      events << @conn.createFilter(transmitterID, 'transmitter', 'network')
      events << @conn.createFilter(@airMixerID, 'videoMixer', 'master')
      events << @conn.createFilter(@previewMixerID, 'videoMixer', 'master')
      events << @conn.createFilter(airEncoderID, 'videoEncoder', 'master')
      events << @conn.createFilter(previewEncoderID, 'videoEncoder', 'master')
      events << @conn.createFilter(airResamplerEncoderID, 'videoResampler', 'master')
      events << @conn.createFilter(previewResamplerEncoderID, 'videoResampler', 'master')
      events << @conn.createFilter(@audioMixer, 'audioMixer', 'master')
      events << @conn.createFilter(audioEncoder, 'audioEncoder', 'master')
      sendRequest(events);

      updateDataBase

      events = []
      events << configureResampler(airResamplerEncoderID, 0, 0, {:pixelFormat => 2})
      events << configureResampler(previewResamplerEncoderID, 0, 0, {:pixelFormat => 2})
      events << configureAudioEncoder(audioEncoder, {:channels => 2, :sampleRate => 48000, :codec => 'aac'})
      sendRequest(events);

      assignWorker(transmitterID, 'transmitter', 'network', 'livemedia')
      assignWorker(receiverID, 'receiver', 'network', 'livemedia')
      assignWorker(@airMixerID, 'videoMixer', 'master', 'worker')
      assignWorker(@previewMixerID, 'videoMixer', 'master', 'worker')
      assignWorker(airEncoderID, 'videoEncoder', 'master', 'worker')
      assignWorker(previewEncoderID, 'videoEncoder', 'master', 'worker')
      assignWorker(airResamplerEncoderID, 'videoResampler', 'master', 'worker', {:processorLimit => 2})
      assignWorker(previewResamplerEncoderID, 'videoResampler', 'master', 'worker', {:processorLimit => 2})
      assignWorker(@audioMixer, 'audioMixer', 'master', 'worker')
      assignWorker(audioEncoder, 'audioEncoder', 'master', 'worker')

      createPath(airOutputPathID, @airMixerID, transmitterID, [airResamplerEncoderID, airEncoderID])
      createPath(previewOutputPathID, @previewMixerID, transmitterID, [previewResamplerEncoderID, previewEncoderID])
      createPath(audioPathID, @audioMixer, transmitterID, [audioEncoder])

      #OUTPUT
      audioPath = @db.getPath(audioPathID)
      airPath = @db.getPath(airOutputPathID)
      previewPath = @db.getPath(previewOutputPathID)

      airTxSessionID = Random.rand(@randomSize)
      previewTxSessionID = Random.rand(@randomSize)

      events = []
      events << @conn.addRTSPOutputSession(transmitterID, airTxSessionID, [airPath["destinationReader"], audioPath["destinationReader"]], 'air', 'mpegts')
      events << @conn.addRTSPOutputSession(transmitterID, previewTxSessionID, [previewPath["destinationReader"]], 'preview', 'mpegts')
      sendRequest(events)

      @started = true

      updateDataBase
    end

    def updateDataBase
      stateHash = sendRequest(getState)
      @db.update(stateHash)
    end

    def getAVMixerState(grid = '2x2')
      updateDataBase
      avmstate = {}
      avmstate[:video] = @db.getVideoMixerState(@airMixerID, grid)
      avmstate[:audio] = @db.getAudioMixerState
      return avmstate
    end

    def createPath(id, orgFilterId, dstFilterId, midFiltersIds, options = {})
      orgWriterId = (options[:orgWriterId].to_i != 0) ? options[:orgWriterId].to_i : -1
      dstReaderId = (options[:dstReaderId].to_i != 0) ? options[:dstReaderId].to_i : -1
      sendRequest(@conn.createPath(id, orgFilterId, dstFilterId, orgWriterId, dstReaderId, midFiltersIds)  )
      updateDataBase
    end

    def addRTSPSession(vChannel, aChannel, progName, uri)
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

      vChCount = 0
      aChCount = 0
      session[:subsessions].each do |s|
        if s[:medium] == 'audio'
          @db.addAudioChannelPort(aChannel + aChCount, s[:port])
          createAudioInputPath(s[:port])
          aChCount += 1
        elsif s[:medium] == 'video'
          @db.addVideoChannelPort(vChannel + vChCount, s[:port])
          createVideoInputPaths(s[:port])
          applyPreviewGrid
          vChCount += 1
        end
      end
    end

    def addRTPSession(medium, params, bandwidth, timeStampFrequency)
      #TODO CHECK IF PORT ALREADY OCCUPYED!!!
      port = params[:port].to_i
      return if port == 0

      codec = params[:codec]

      case medium
      when "audio"
        mixerChannel = params[:channel].to_i
        channels = params[:channels].to_i
        timeStampFrequency = params[:sampleRate].to_i

        receiver = @db.getFilterByType('receiver')

        #TODO manage response
        sendRequest(@conn.addRTPSession(receiver["id"], port, medium, codec, bandwidth, timeStampFrequency, channels))

        @db.addAudioChannelPort(mixerChannel, port)
        createAudioInputPath(port)
        updateDataBase
      when "video"
        mixerChannel = params[:channel].to_i

        receiver = @db.getFilterByType('receiver')

        #TODO manage response
        sendRequest(@conn.addRTPSession(receiver["id"], port, medium, codec, bandwidth, timeStampFrequency, channels))

        @db.addVideoChannelPort(mixerChannel, port)
        createVideoInputPaths(port)
        applyPreviewGrid

        updateDataBase
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

    # Adds an output RTP transmision
    # @param output [String] the output content, "air" or "preview"
    # @param txFormat [String] the tx format type, "std", "ultragrid" or "mpegts"
    # @param ip [String] the destination ip
    # @param port [Numeric] the destination port
    # @return [String] the object converted into the expected format.
    def addOutputRTPtx(output, txFormat, ip, port)
      txId = @db.getFilterByType('transmitter')["id"]
      case output
      when "air"
        videoPath = getOutputPathFromFilter(@airMixerID)
        audioPath = getOutputPathFromFilter(@audioMixer)

        videoId = Random.rand(@randomSize)
        audioId = Random.rand(@randomSize)

        if txFormat == "mpegts"
          response = sendRequest(
                      @conn.addOutputRTPtx(txId, [videoPath["destinationReader"], 
                                           audioPath["destinationReader"]], 
                                           videoId, ip, port, txFormat)
                      )
        else
          response = sendRequest(
                      @conn.addOutputRTPtx(txId, [videoPath["destinationReader"]], 
                                 videoId, ip, port, txFormat)
                      )

          response = sendRequest(
                      @conn.addOutputRTPtx(txId, [audioPath["destinationReader"]], 
                                 audioId, ip, port+2, txFormat)
                     )
        end

      when "preview"
        videoPath = getOutputPathFromFilter(@previewMixerID)
        videoId = Random.rand(@randomSize)

        response = sendRequest(
                    @conn.addOutputRTPtx(txId, [videoPath["destinationReader"]], 
                                 videoId, ip, port, txFormat)
                   )

      else
        raise MixerError, "Error, wrong RTP output option"
      end

      raise MixerError, response[:error] if response[:error]
    end

    def assignWorker(filterId, filterType, filterRole, workerType, options = {})
      processorLimit = (options[:processorLimit]) ? options[:processorLimit] : 0

      @db.getWorkerByType(workerType, filterRole, filterType).each do |w|
        if processorLimit == 0 || processorLimit > w["processors"].size
          sendRequest(@conn.addFiltersToWorker(w["id"], [filterId]))
          @db.addProcessorToWorker(w["id"], filterId, filterRole, filterType)
          return w["id"]
        end
      end

      newWorker = Random.rand(@randomSize)
      sendRequest(addWorker(newWorker, workerType))
      @db.addWorker(newWorker, workerType, filterRole, filterType)
      sendRequest(@conn.addFiltersToWorker(newWorker, [filterId]))
      @db.addProcessorToWorker(newWorker, filterId, filterRole, filterType)
      return newWorker
    end

    #################
    # AUDIO METHODS #
    #################

    def muteMaster
      sendRequest(@conn.muteMaster(@audioMixer))
    end

    def muteChannel(channel)
      port = @db.getAudioChannelPort(channel)
      if port
        sendRequest(@conn.muteChannel(@audioMixer, port))
      end
    end

    def soloChannel(channel)
      port = @db.getAudioChannelPort(channel)
      if port
        sendRequest(@conn.soloChannel(@audioMixer, port))
      end
    end

    def changeMasterVolume(volume)
      sendRequest(@conn.changeMasterVolume(@audioMixer, volume))
    end

    def changeChannelVolume(channel, volume)
      port = @db.getAudioChannelPort(channel)
      if port
        sendRequest(@conn.changeChannelVolume(@audioMixer, port, volume))
      end
    end

    #################
    # VIDEO METHODS #
    #################

    def applyPreviewGrid
      grid = @db.getGrid('preview')
      mixer = getFilter(@previewMixerID)

      events = []

      grid["positions"].each do |p|
        mixerChannelId = @db.getVideoChannelPort(p["id"])

        unless mixerChannelId == 0
          path = getPathByDestination(@previewMixerID, mixerChannelId)
          resamplerId = path["originFilter"]

          width = p["width"]*mixer["width"]
          height = p["height"]*mixer["height"]

          events << configureResampler(resamplerId, width, height)
          events << setPositionSize(@previewMixerID, mixerChannelId,
                                    p["width"], p["height"], p["x"],
                                    p["y"], p["layer"], p["opacity"]
                                   )
                                    
        end
      end

      sendRequest(events)
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
      events = []

      mixer["channels"].each do |ch|
        position = {}

        grid["positions"].each do |p|
          if ch["id"] == @db.getVideoChannelPort(p["channel"])
            position = p
          end
        end

        if position.empty?
          ch["enabled"] = false
          events << updateVideoChannel(@airMixerID, ch)
        else
          ch["width"] = position["width"]
          ch["height"] = position["height"]
          ch["x"] = position["x"]
          ch["y"] = position["y"]
          ch["layer"] = position["layer"]
          ch["opacity"] = position["opacity"]
          ch["enabled"] = true

          events << updateVideoChannel(@airMixerID, ch)

          path = getPathByDestination(@airMixerID, ch["id"])
          resamplerID = path["filters"][1]

          width = ch["width"]*mixer["width"]
          height = ch["height"]*mixer["height"]

          events << configureResampler(resamplerID, width, height)

        end
      end

      sendRequest(events)

      updateFilter(mixer)
    end

    def commute(channel)
      @db.resetGrids
      mixer = getFilter(@airMixerID)
      port = @db.getVideoChannelPort(channel)
      events = []

      mixer["channels"].each do |ch|
        if ch["id"] == port
          ch["width"] = 1
          ch["height"] = 1
          ch["x"] = 0
          ch["y"] = 0
          ch["layer"] = 1
          ch["opacity"] = 1.0
          ch["enabled"] = true

          events << updateVideoChannel(@airMixerID, ch)

          path = getPathByDestination(@airMixerID, ch["id"])
          resamplerID = path["filters"][1]

          width = ch["width"]*mixer["width"]
          height = ch["height"]*mixer["height"]

          events << configureResampler(resamplerID, width, height)
        else
          ch["enabled"] = false
          events << updateVideoChannel(@airMixerID, ch)
        end
      end

      sendRequest(events)
      updateFilter(mixer)
    end

    def fade(channel, time)
      mixer = getFilter(@airMixerID)
      port = @db.getVideoChannelPort(channel)
      path = getPathByDestination(@airMixerID, port)
      resamplerID = path["filters"][1]
      events = []

      intervals = (time/@videoFadeInterval)
      deltaOp = 1.0/intervals

      mixer["channels"].each do |ch|
        if ch["layer"] >= mixer["maxChannels"] - 1
          ch["layer"] = mixer["maxChannels"] - 2
          events << updateVideoChannel(@airMixerID, ch)
        end
      end

      events << configureResampler(resamplerID, mixer["width"], mixer["height"])

      intervals.times do |d|
        event = setPositionSize(@airMixerID, port, 1, 1, 0, 0, mixer["maxChannels"] - 1, d*deltaOp)
        event[:delay] = d*@videoFadeInterval
        events << event
      end

      mixer["channels"].each do |ch|
        if ch["id"] == port
          ch["width"] = 1
          ch["height"] = 1
          ch["x"] = 0
          ch["y"] = 0
          ch["layer"] = mixer["maxChannels"] - 1
          ch["opacity"] = 1.0
          ch["enabled"] = true

          event = updateVideoChannel(@airMixerID, ch)
          event[:delay] = intervals*@videoFadeInterval
          events << event

        else
          ch["enabled"] = false
          event = updateVideoChannel(@airMixerID, ch)
          event[:delay] = intervals*@videoFadeInterval
          events << event
        end
      end

      sendRequest(events)
      updateFilter(mixer)

    end

    def blend(channel)
      mixer = getFilter(@airMixerID)
      port = @db.getVideoChannelPort(channel)
      path = getPathByDestination(@airMixerID, port)
      resamplerID = path["filters"][1]
      events = []

      mixer["channels"].each do |ch|
        if ch["layer"] >= mixer["maxChannels"] - 1
          ch["layer"] = mixer["maxChannels"] - 2
          events << updateVideoChannel(@airMixerID, ch)
        end
      end

      events << configureResampler(resamplerID, mixer["width"], mixer["height"])

      mixer["channels"].each do |ch|
        if ch["id"] == port
          ch["width"] = 1
          ch["height"] = 1
          ch["x"] = 0
          ch["y"] = 0
          ch["layer"] = mixer["maxChannels"] - 1
          ch["opacity"] = 0.5
          ch["enabled"] = true

          events << updateVideoChannel(@airMixerID, ch)
        end
      end

      sendRequest(events)
      updateFilter(mixer)

    end

    def createVideoInputPaths(port)
      receiver = @db.getFilterByType('receiver')
      events = []

      decoderId = Random.rand(@randomSize)
      airResamplerId = Random.rand(@randomSize)
      previewResamplerId = Random.rand(@randomSize)
      masterPathId = Random.rand(@randomSize)
      slavePathId = Random.rand(@randomSize)


      events << @conn.createFilter(decoderId, 'videoDecoder', 'master')
      events << @conn.createFilter(airResamplerId, 'videoResampler', 'master')
      events << @conn.createFilter(previewResamplerId, 'videoResampler', 'slave')
      sendRequest(events)
      updateDataBase

      createPath(masterPathId, receiver["id"], @airMixerID, [decoderId, airResamplerId], {:orgWriterId => port, :dstReaderId => port})
      createPath(slavePathId, previewResamplerId, @previewMixerID, [], {:dstReaderId => port})

      sendRequest(addSlavesToFilter(airResamplerId, [previewResamplerId]))
      
      assignWorker(decoderId, 'videoDecoder', 'master', 'worker', {:processorLimit => 2})
      assignWorker(airResamplerId, 'videoResampler', 'master', 'worker', {:processorLimit => 1})
      assignWorker(previewResamplerId, 'videoResampler', 'slave', 'worker', {:processorLimit => 2})

      sendRequest(configureResampler(previewResamplerId, 0, 0))
    end

    def createAudioInputPath(port)
      receiver = @db.getFilterByType('receiver')

      decoderID = Random.rand(@randomSize)
      decoderPathID = Random.rand(@randomSize)

      sendRequest(@conn.createFilter(decoderID, 'audioDecoder', 'master'))
      createPath(decoderPathID, receiver["id"], @audioMixer, [decoderID], {:orgWriterId => port, :dstReaderId => port})

      assignWorker(decoderID, 'audioDecoder', 'master', 'worker')
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
