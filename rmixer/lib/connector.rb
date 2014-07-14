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

require 'socket'
require 'json'

module RMixer

  # ==== Overview
  # Class that allows the module to connect with a remote mixer instance and communicate
  # with it using, under the hood, the <b>Mixer JSON API</b>.
  #
  # ==== TCP Socket Usage
  # A RMixer::Connector instance creates a new TCP connection for each method.
  # This means that multiple instances of this class can be working at the
  # same time without blocking each other.
  #
  class Connector

    # Remote mixer host address
    attr_reader :host
    # Remote mixer port address
    attr_reader:port

    # Initializes a new RMixer::Connector instance.
    #
    # ==== Attributes
    #
    # * +host+ - Remote mixer host address
    # * +port+ - Remote mixer port address
    # * +eventArray+ - Array for sending events
    # * +testing+ - Optional testing parameter. If set to +:request+, changes
    #   the behaviour of RMixer::Connector#get_response
    #
    def initialize(host, port, testing = nil)
      @host = host
      @port = port
      @testing = testing
      @eventArray = []
    end

    def addRTPSession(filterID, port, medium, codec, bandwidth, timeStampFrequency, channels)
      subsessions = []
      subsession = {
        :port => port,
        :medium => medium,
        :codec => codec,
        :bandwidth => bandwidth,
        :timeStampFrequency => timeStampFrequency,
        :channels => channels
      }

      subsessions << subsession

      params = {
        :subsessions => subsessions
      }

      createEvent("addSession", params, filterID)
    end

    def addRTSPSession (filterID, progName, uri)
      params = {
        :progName => progName,
        :uri => uri
      }
      createEvent("addSession", params, filterID)
    end

    def addOutputSession(filterID, readers)
      if readers.length > 0
        params = {
          :readers => readers
        }
        createEvent("addSession", params, filterID)
      end
    end

    def getState
      createEvent("getState")
    end

    def addOutputSession(txID, readers, sessionName)
      params = {
        :readers => readers,
        :sessionName => sessionName
      }

      createEvent("addSession", params, txID)
    end

    def addOutputSessionTemporal(txID, readers, sessionName)
      params = {
        :readers => readers,
        :sessionName => sessionName
      }

      createEvent("addSession", params, txID)
    end

    def createFilter(id, type)
      params = {
        :id => id,
        :type => type,
      }

      createEvent("createFilter", params)
    end

    def createPath(id, orgFilterId, dstFilterId, orgWriterId, dstReaderId, midFiltersIds, sharedQueue = false)
      params = {
        :id => id,
        :orgFilterId => orgFilterId,
        :dstFilterId => dstFilterId,
        :orgWriterId => orgWriterId,
        :dstReaderId => dstReaderId,
        :midFiltersIds => midFiltersIds,
        :sharedQueue => sharedQueue
      }

      createEvent("createPath", params)
    end

    def addWorker(id, type, fps = 24)
      params = {
        :id => id,
        :type => type,
        :fps => fps
      }

      createEvent("addWorker", params)
    end

    def addSlavesToWorker(master, slaves)
      params = {
        :master => master,
        :slaves => slaves
      }

      createEvent("addSlavesToWorker", params)
    end

    def addFiltersToWorker(worker, filters)
      params = {
        :worker => worker,
        :filters => filters
      }

      createEvent("addFiltersToWorker", params)
    end

    #AUDIO METHODS

    def changeChannelVolume(filterID, id, volume) 
      params = {
        :id => id,
        :volume => volume
      }
      createEvent("changeChannelVolume", params, filterID)
    end

    def muteChannel(filterID, id) 
      params = {
        :id => id
      }
      createEvent("muteChannel", params, filterID)
    end

    def soloChannel(filterID, id) 
      params = {
        :id => id
      }
      createEvent("soloChannel", params, filterID)
    end

    def changeMasterVolume(filterID, volume) 
      params = {
        :volume => volume
      }
      createEvent("changeMasterVolume", params, filterID)
    end

    def muteMaster(filterID) 
      params = {}
      createEvent("muteMaster", params, filterID)
    end

    def configAudioEncoder(filterID, sampleRate, channels)
      params = {
        :sampleRate => sampleRate,
        :channels => channels
      }

      createEvent("configure", params, filterID)
    end

    def reconfigAudioEncoder(encoderID, codec, sampleRate, channels)
      params = {
        :encoderID => encoderID,
        :codec => codec,
        :sampleRate => sampleRate,
        :channels => channels
      }
      
      createEvent("reconfigAudioEncoder", params)
    end

    #VIDEO METHODS

    def setPositionSize(mixerID, id, width, height, x, y, layer, opacity, enabled = true)
      params = {
        :id => id,
        :width => width,
        :height => height,
        :x => x,
        :y => y,
        :layer => layer,
        :opacity => opacity,
        :enabled => enabled
      }
      
      createEvent("configChannel", params, mixerID)
    end

    def updateVideoChannel(mixerId, channel)
      params = {
        :id => channel["id"],
        :width => channel["width"],
        :height => channel["height"],
        :x => channel["x"],
        :y => channel["y"],
        :layer => channel["layer"],
        :opacity => channel["opacity"],
        :enabled => channel["enabled"]
      }

      createEvent("configChannel", params, mixerId)
    end

    def configureResampler(resamplerID, width, height, options = {})
      params = {
        :width => width,
        :height => height
      }

      if options[:pixelFormat]
        params[:pixelFormat] = options[:pixelFormat]
      end

      if options[:discartPeriod]
        params[:discartPeriod] = options[:discartPeriod]
      end

      createEvent("configure", params, resamplerID)
    end

    def configureVideoEncoder(encoderId, options = {})
      params = {}

      if options[:fps]
        params[:fps] = options[:fps]
      end

      if options[:gop]
        params[:gop] = options[:gop]
      end

      if options[:bitrate]
        params[:bitrate] = options[:bitrate]
      end

      if options[:threads]
        params[:threads] = options[:threads]
      end

      if options[:annexb]
        params[:annexb] = options[:annexb]
      end

      createEvent("configure", params, encoderId)
    end


    # Method that composes the JSON request and sends it over TCP to the
    # targetted remote mixer instance.
    #
    # Returns the Mixer's JSON response converted to a hash unless the
    # RMixer::Mixer was initialized with <tt>testing = :request</tt> option.
    #
    # ==== Testing 
    #
    # If <tt>@testing == :request</tt>, this method returns the hash that should
    # be sent over TCP without actually sending it.
    #
    # ==== Debugging
    #
    # This method is intended to be used internally, but is exposed since
    # it's useful for debugging.
    #
    # ==== Attributes
    # 
    # * +action+ - The action to be sent
    # * +params+ - Optional hash containing the parameters to be sent
    #
    # ==== Examples
    #   
    #   mixer = RMixer::Mixer.new "localhost", 7777
    #   mixer.get_response("start_mixer", { :width => 1280, :height => 720 })   
    #

    def createEvent(action, params = {}, filterID = 0)
      event = {
        :action => action,
        :params => params,
        :filterID => filterID
      }
    end

    def sendRequest(events = @eventArray)
      request = {
        :events => events
      }
      s = TCPSocket.open(@host, @port)
      s.print(request.to_json)
      puts
      puts request
      response = s.recv(4096*4) # TODO: max_len ?
      puts
      puts response
      puts
      s.close
      @eventArray.clear
      return JSON.parse(response, :symbolize_names => true)
    end

    def appendEvent(event, delay = 0)
      event[:delay] = delay
      @eventArray << event
      return {:error => nil}
    end

  end

end
