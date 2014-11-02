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

require 'mongo'

include Mongo

module RMixer

  # ==== Overview
  # Class that manages MongoDB access
  
  class MongoMngr

    # Database server host
    attr_reader :host
    # Database server port
    attr_reader:port
    # Database name
    attr_reader:dbname

    # Initializes a new RMixer::Connector instance.
    #
    # ==== Attributes
    #
    # * +host+ - Database server host
    # * +port+ - Database server port
    # * +dbname+ - Database name

    def initialize(host = 'localhost', port = MongoClient::DEFAULT_PORT, dbname = 'livemediastreamer')
      @host = host
      @port = port
      @dbname = dbname
      db = MongoClient.new(host, port).db(dbname)
      db.collection_names.each do |name|
        db.drop_collection(name)
      end
    end

    def k2s
      lambda do |h|
        Hash === h ?
          Hash[
            h.map do |k, v|
              [k.respond_to?(:to_s) ? k.to_s : k, k2s[v]]
            end
          ] : h
      end
    end

    def update (stateHash)
      db = MongoClient.new(host, port).db(dbname)
      paths = db.collection('paths')
      filters = db.collection('filters')

      paths.remove
      filters.remove

      stateHash[:filters].each do |h|
        filters.insert(h)
      end

      stateHash[:paths].each do |h|
        paths.insert(h)
      end
    end

    def clear
      db = MongoClient.new(host, port).db(dbname)
      db.collection_names.each do |name|
        db.drop_collection(name)
      end
    end

    def getWorkerByType(workerType, filterType, fps = 24)
      db = MongoClient.new(host, port).db(dbname)
      workers = db.collection('workers')

      workers.find({:workerType => workerType, 
                    :filterType => filterType,
                    :fps => fps
                    }
                  )
    end

    def addWorker(id, workerType, filterType, fps = 24)
      db = MongoClient.new(host, port).db(dbname)
      workers = db.collection('workers')

      processors = []

      w = {
        :id => id,
        :workerType => workerType,
        :filterType => filterType,
        :processors => processors,
        :fps => fps
      }

      workers.insert(w)
    end

    def addProcessorToWorker(workerId, filterId, filterType)
      db = MongoClient.new(host, port).db(dbname)
      workers = db.collection('workers')

      w = workers.find({:id => workerId, :filterType => filterType}).first

      w["processors"] << {"id" => filterId, "type" => filterType}

      workers.update({:id => workerId}, w)
    end

    def updateFilter(filter)
      db = MongoClient.new(host, port).db(dbname)
      filters = db.collection('filters')

      filters.update({:id => filter["id"]}, filter)
    end

    def loadGrids(gridsArray)
      db = MongoClient.new(host, port).db(dbname)
      grids = db.collection('grids')

      gridsArray.each do |g|
        grids.insert(g)
      end
    end

    def getGrid(gridId)
      db = MongoClient.new(host, port).db(dbname)
      grids = db.collection('grids')

      grid = grids.find(:id => gridId).first
    end

    def updateGrid(grid)
      db = MongoClient.new(host, port).db(dbname)
      grids = db.collection('grids')

      grids.update({:id => grid["id"]}, grid)
    end

    def resetGrids
      db = MongoClient.new(host, port).db(dbname)
      grids = db.collection('grids')

      grids.find.each { |g| 
        g["positions"].each do |p|
          p["channel"] = 0
        end
      }
    end

    def addVideoChannelPort(chID, chPort)
      db = MongoClient.new(host, port).db(dbname)
      videoChannelPort = db.collection('videoChannelPort')

      channelPort = {
        :channel => chID,
        :port => chPort
      }

      videoChannelPort.insert(channelPort)
    end

    def getVideoChannelPort(chID)
      db = MongoClient.new(host, port).db(dbname)
      videoChannelPort = db.collection('videoChannelPort')

      channelPort = videoChannelPort.find(:channel => chID).first

      if channelPort
        return channelPort["port"]
      else
        return 0
      end
    end

    def addAudioChannelPort(channel, chPort)
      db = MongoClient.new(host, port).db(dbname)
      audioChannelPort = db.collection('audioChannelPort')

      channelPort = {
        :channel => channel,
        :port => chPort
      }

      audioChannelPort.insert(channelPort)
    end

    def getAudioChannelPort(channel)
      db = MongoClient.new(host, port).db(dbname)
      audioChannelPort = db.collection('audioChannelPort')

      channelPort = audioChannelPort.find(:channel => channel).first

      if channelPort
        return channelPort["port"]
      end
    end

    def getAudioMixerState
      db = MongoClient.new(host, port).db(dbname)
      filters = db.collection('filters')
      paths = db.collection('paths')
      audioChannelPort = db.collection('audioChannelPort')

      mixer = filters.find(:type=>"audioMixer").first

      mixerHash = {}

      if mixer["gains"]
        mixer["gains"].each do |g|
          channelPort = audioChannelPort.find(:port => g["id"]).first
          g["channel"] = channelPort["channel"]
        end
      end

      mixerHash["maxChannels"] = 8
      mixerHash["channels"] = mixer["gains"].sort_by {|ch| ch["channel"]}
      mixerHash["masterGain"] = mixer["masterGain"]

      return mixerHash
    end

    def getVideoMixerState(mixerID, grid)
      db = MongoClient.new(host, port).db(dbname)
      grids = db.collection('grids')
      filters = db.collection('filters')
      videoChannelPort = db.collection('videoChannelPort')

      grid = grids.find(:id => grid).first
      mixer = filters.find(:id => mixerID).first
      transmitter = filters.find(:type=>"transmitter").first
      
      mixerHash = {"grid" => grid}
      mixerHash["maxChannels"] = 8
      if transmitter["sessions"]
        mixerHash["sessions"] = transmitter["sessions"]
      end

      if mixer["channels"]
        mixer["channels"].each do |ch|
          channelPort = videoChannelPort.find(:port => ch["id"]).first
          ch["channel"] = channelPort["channel"]
        end
        mixerHash["channels"] = mixer["channels"].sort_by {|ch| ch["channel"]}
      end
      return mixerHash
    end

    def getOutputPathFromFilter(mixerID, writer = 0)
      db = MongoClient.new(host, port).db(dbname)
      paths = db.collection('paths')

      if writer == 0
        path = paths.find(:originFilter=>mixerID).first
      end
      
      return path

    end

    def getPathByDestination(filter, reader = 1)
      db = MongoClient.new(host, port).db(dbname)
      paths = db.collection('paths')

      path = paths.find({:destinationFilter=>filter,:destinationReader=>reader}).first
    end

    def getFilterByType(type)
      db = MongoClient.new(host, port).db(dbname)
      filters = db.collection('filters')

      filter = filters.find(:type=>type).first
    end

    def getFilter(filterID)
      db = MongoClient.new(host, port).db(dbname)
      filters = db.collection('filters')

      filter = filters.find(:id=>filterID).first
    end

    def getPath(pathID)
      db = MongoClient.new(host,port).db(dbname)
      paths = db.collection('paths')

      path = paths.find(:id=>pathID).first
    end
    
    def updateChannelVolume(id, volume)
      db = MongoClient.new(host, port).db(dbname)
      filters = db.collection('filters')

      mixer = filters.find(:type=>"audioMixer").first

      if mixer["gains"]
        mixer["gains"].each do |g|
          if g["id"] == id 
            g["volume"] = volume
          end
        end
      end
    end

  end
end
