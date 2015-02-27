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

require 'rubygems'
require 'bundler/setup'
require 'sinatra/base'
require 'rack/protection'
require 'socket'
require 'json'

class MITSUdemoAPI < Sinatra::Base

    configure do
    set :show_exceptions, false
    end

    not_found do
    content_type :json
    msg = "no path to #{request.path}"
    { :msg => msg }.to_json
    end

    error do
    content_type :json
    msg = "Error is:  #{params[:captures].first.inspect}"
    { :msg => msg }.to_json
    end

    helpers do
    def isNumber?(object)
      true if Float(object) rescue false
    end
    end

    # Web App Methods
    # Routes
    get '/' do
        redirect '/app'
    end

    get '/app' do
        redirect '/app/demo'
    end

    get '/app/demo' do
        send_file 'public/demo.html'
    end

    ###################
    # GENERAL METHODS #
    ###################

    post '/app/demo/bitrate' do
        content_type :json
        config = {
            :bitrate => params[:bitrate].to_i
        }
        puts "received new bitrate config"
        puts config
        sendRequest(createEvent("configure", config, 1000))
    end

    post '/app/demo/size' do
        content_type :json
        config = {
            :width => params[:width].to_i,
            :height => params[:height].to_i
        }
        puts "received new size config"
        puts config
        sendRequest(createEvent("configure", config, 2000))
    end

    post '/app/demo/fps' do
        content_type :json
        config = {
            :fps => params[:fps].to_i
        }
        puts "received new fps config"
        puts config
        sendRequest(createEvent("configure", config, 1000))
    end

    def createEvent(action, params, filterID)
        event = {
            :action => action,
            :params => params,
            :filterID => filterID
        }
    end

    def sendRequest(events)
        request = {
        :events => events
        }
        puts "sending msg socket"
        s = TCPSocket.open('127.0.0.1', 7777)
        s.print(request.to_json)
        puts request
        response = s.recv(4096*4) # TODO: max_len ?
        puts
        puts response
        puts
        s.close
        return response
    end


end
