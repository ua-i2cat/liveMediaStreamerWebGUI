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
require "append"
require "grids"
require "ultragrid"
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
      @uv = RMixer::UltraGridRC.new
      @started = false
      @lmsStarted = false
      @lmsThread = nil
      @lmspid = nil
      @randomSize = 2**16
      @videoFadeInterval = 50 #ms
    end

    def check_livemediastreamer_installation
      if !(find_executable 'livemediastreamer').nil?
        puts "livemediastreamer already installed...going to run"
        return true
      else
        puts "livemediastreamer not installed...please install on system before running GUI"
        return false
      end
    end
    
    def check_livemediastreamer_process
      if `ps aux | grep livemediastreamer | grep --invert grep` != ""
        found = `ps aux | grep livemediastreamer | grep --invert grep`
        tmpPid = `ps aux | grep livemediastreamer | grep --invert grep |awk '{ print $2 }'`
        puts "Previous livemediastreamer instance found (#{found} -> PID = #{tmpPid}): restarting..."
        Process.kill("TERM", tmpPid.to_i)
      else
        puts "No previous livemediastreamer instance found: starting..."
      end
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
      sendRequest(reset)
    end

    def start
      if !@lmsStarted && check_livemediastreamer_installation
        check_livemediastreamer_process
        run_livemediastreamer
        sleep(1)
        if @lmsStarted
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
    
          airEncoderFPS = 25
    
          assignWorker(@airMixerID, 'videoMixer', 'master')
          assignWorker(@previewMixerID, 'videoMixer', 'master')
          assignWorker(airEncoderID, 'videoEncoder', 'master')
          assignWorker(previewEncoderID, 'videoEncoder', 'master')
          assignWorker(airResamplerEncoderID, 'videoResampler', 'master')
          assignWorker(previewResamplerEncoderID, 'videoResampler', 'master')
    
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
    
          assignWorker(@audioMixer, 'audioMixer', 'master')
          assignWorker(audioEncoder, 'audioEncoder', 'master')
    
          #OUTPUT
    
          sendRequest(@conn.addOutputSession(txId, [airPath["destinationReader"], audioPath["destinationReader"]], 'air'))
          sendRequest(@conn.addOutputSession(txId, [previewPath["destinationReader"]], 'preview'))
          @started = true 

          updateDataBase
        else
          puts "livemediastreamer not started...check system processes...!"
        end
      else
        puts "livemediastreamer already running...ambiguous situation...!"
      end
    end

    def run_livemediastreamer
      return if isStarted #force only one process
      cmd = "livemediastreamer 7777"
      puts cmd
      #run thread livemediastreamer (parsing std and output stdout and stderr)
      @lmsThread = Thread.new do   # Calling a class method new
        begin
          puts "Starting livemediastreamer"
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

    def assignWorker(filterId, filterType, workerType, options = {})
      processorLimit = (options[:processorLimit]) ? options[:processorLimit] : 0

      @db.getWorkerByType(workerType, filterType).each do |w|
        if processorLimit == 0 || processorLimit > w["processors"].size
          sendRequest(addFiltersToWorker(w["id"], [filterId]))
          @db.addProcessorToWorker(w["id"], filterId, filterType)
          return w["id"]
        end
      end

      newWorker = Random.rand(@randomSize)
      sendRequest(addWorker(newWorker, workerType))
      @db.addWorker(newWorker, workerType, filterType)
      sendRequest(addFiltersToWorker(newWorker, [filterId]))
      @db.addProcessorToWorker(newWorker, filterId, filterType)
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

    def blend(channel)
      mixer = getFilter(@airMixerID)
      port = @db.getVideoChannelPort(channel)
      path = getPathByDestination(@airMixerID, port)
      resamplerID = path["filters"].first

      mixer["channels"].each do |ch|
        if ch["layer"] >= 7
          ch["layer"] = 6
          appendEvent(updateVideoChannel(@airMixerID, ch))
        end
      end

      appendEvent(configureResampler(resamplerID, mixer["width"], mixer["height"]))

      mixer["channels"].each do |ch|
        if ch["id"] == port
          ch["width"] = 1
          ch["height"] = 1
          ch["x"] = 0
          ch["y"] = 0
          ch["layer"] = 7
          ch["opacity"] = 0.5
          ch["enabled"] = true

          appendEvent(updateVideoChannel(@airMixerID, ch))
        end
      end

      sendRequest
      updateFilter(mixer)

    end

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

      assignWorker(decoderID, 'videoDecoder', 'master', {:processorLimit => 2})
      master = assignWorker(airResamplerID, 'videoResampler', 'master', {:processorLimit => 2})
      slave = assignWorker(previewResamplerID, 'videoResampler', 'slave', {:processorLimit => 2})

      sendRequest(addSlavesToWorker(master, [slave]))
      sendRequest(configureResampler(previewResamplerID, 0, 0))
    end

    def createAudioInputPath(port)
      receiver = @db.getFilterByType('receiver')

      decoderID = Random.rand(@randomSize)
      decoderPathID = Random.rand(@randomSize)

      createFilter(decoderID, 'audioDecoder')
      createPath(decoderPathID, receiver["id"], @audioMixer, [decoderID], {:orgWriterId => port, :dstReaderId => port})

      assignWorker(decoderID, 'audioDecoder', 'master')
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
