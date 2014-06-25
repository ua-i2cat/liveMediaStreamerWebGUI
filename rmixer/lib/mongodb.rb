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

    def getAudioMixerState
      db = MongoClient.new(host, port).db(dbname)
      filters = db.collection('filters')
      paths = db.collection('paths')

      mixer = filters.find(:type=>"audioMixer").first


      gains = []
      mixerHash = {}

      if mixer["gains"]
        mixer["gains"].each do |g|
          gains << k2s[g]
        end
      end
      
      mixerHash[:channels] = gains
      mixerHash[:freeChannels] = 8 - gains.size
      mixerHash[:mixerID] = mixer["id"]
      mixerHash[:masterGain] = mixer["masterGain"]
      mixerHash[:masterDelay] = mixer["masterDelay"]
      return k2s[mixerHash]
    end

    def getReceiverID
      db = MongoClient.new(host, port).db(dbname)
      filters = db.collection('filters')

      receiver = filters.find(:type=>"receiver").first

      return receiver["id"]
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
