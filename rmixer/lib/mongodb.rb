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

    def addVideoChannelPort(chID, chPort)
      db = MongoClient.new(host, port).db(dbname)
      videoChannelPort = db.collection('videoChannelPort')

      channelPort = {
        :channel => chID,
        :port => chPort
      }

      videoChannelPort.insert(channelPort)
    end

    def getAudioMixerState
      db = MongoClient.new(host, port).db(dbname)
      filters = db.collection('filters')
      paths = db.collection('paths')
      outputSessions = db.collection('outputSessions')

      mixer = filters.find(:type=>"audioMixer").first
      transmitter = filters.find(:type=>"transmitter").first
      encoderPath = paths.find(:originFilter=>mixer["id"]).first
      encoder = filters.find(:id=>encoderPath["filters"].first).first

      gains = []
      mixerHash = {}
      encoderHash = {}
      session = {}

      if mixer["gains"]
        mixer["gains"].each do |g|
          gains << k2s[g]
        end
      end

      if transmitter["sessions"]
        transmitter["sessions"].each do |s|
          s["readers"].each do |r|
            if r == encoderPath["destinationReader"]
              session["id"] = s["id"]
              session["uri"] = s["uri"]
            end
          end
        end
      end
      
      mixerHash["channels"] = gains
      mixerHash["freeChannels"] = 8 - gains.size
      mixerHash["mixerID"] = mixer["id"]
      mixerHash["masterGain"] = mixer["masterGain"]
      mixerHash["masterDelay"] = mixer["masterDelay"]
      mixerHash["encoder"] = encoder
      mixerHash["session"] = session

      return mixerHash
    end

    def getVideoMixerState(mixerID, grid)
      db = MongoClient.new(host, port).db(dbname)
      grids = db.collection('grids')
      filters = db.collection('filters')

      grid = grids.find(:id => grid).first
      mixer = filters.find(:id => mixerID).first

      if mixer["channels"]
        mixer["channels"].each do |c|

        end
      end

      mixerHash = {"grid" => grid}
      mixerHash["maxChannels"] = 8

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
