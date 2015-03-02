#
#  MTR DEMO MITSU - A management ruby interface for MTR DEMO MITSU
#  Copyright (C) 2013  Fundació i2CAT, Internet i Innovació digital a Catalunya
#
#  This file is part of thin MTR DEMO MITSU project.
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
#  Authors:  Gerard Castillo <gerard.castillo@i2cat.net>
#

require 'rubygems'
require 'bundler/setup'
require 'sinatra/base'
require 'rack/protection'
require 'socket'
require 'json'

class MITSUdemoAPI < Sinatra::Base

    ###################
    # GENERAL CONFIG. #
    ###################
    set :ip, '127.0.0.1'
    set :port, 7777
    set :demoStarted, false
    set :demoThread, nil
    set :demoPID, nil

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

    ##############
    # WEB ROUTES #
    ##############
    get '/' do
        redirect '/app'
    end

    get '/app' do
        redirect '/app/demo'
    end

    get '/app/demo' do
        if settings.demoStarted
            send_file 'public/demo.html'
        else
            send_file 'public/init.html'
        end
    end

    ############
    # API REST #
    ############
    post '/app/demo/start' do
        run_demo(params[:demo])
        redirect ('/app/demo')
    end

    get '/app/demo/stop' do
        stop_demo
        redirect('/app/demo')
    end

    post '/app/demo/bitrate' do
        content_type :json
        config0 = {
            :bitrate => params[:bitrate].to_i
        }
        config1 = {
            :bitrate => params[:bitrate].to_i/2
        }
        config2 = {
            :bitrate => params[:bitrate].to_i/4
        }
        puts "received new bitrate config"
        puts config0
        sendRequest(createEvent("configure", config2, 1002))
        sendRequest(createEvent("configure", config1, 1001))
        sendRequest(createEvent("configure", config0, 1000))
    end

    post '/app/demo/size' do
        content_type :json
        config0 = {
            :width => params[:width].to_i,
            :height => params[:height].to_i
        }
        config1 = {
            :width => params[:width].to_i/2,
            :height => params[:height].to_i/2
        }
        puts "received new size config"
        puts config0
        sendRequest(createEvent("configure", config1, 2002))
        sendRequest(createEvent("configure", config0, 2001))
        sendRequest(createEvent("configure", config0, 2000))
    end

    post '/app/demo/fps' do
        content_type :json
        config = {
            :fps => params[:fps].to_i
        }
        puts "received new fps config"
        puts config
        sendRequest(createEvent("configure", config, 1002))
        sendRequest(createEvent("configure", config, 1001))
        sendRequest(createEvent("configure", config, 1000))
    end

    ###############
    # MSG SOCKETS #
    ###############
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
        s = TCPSocket.open(settings.ip, settings.port)
        s.print(request.to_json)
        puts request
        response = s.recv(4096*4) # TODO: max_len ?
        puts
        puts response
        puts
        s.close
        return response
    end

    #####################
    # PROCES MANAGEMENT #
    #####################
    def run_demo(demo)
        return if settings.demoStarted #force only one process
        case demo
        when "MPEGTS"
            cmd = "testtranscoder -v 5004"
        when "DASH"
            cmd = "testtranscoder -dash"
        else
            puts "You gave me #{demo} -- I have no idea what to do with that."
            return
        end
        #run thread demo (parsing std and output stdout and stderr)
        settings.demoThread = Thread.new do # Calling a class method new
            begin
                Open3.popen2e(cmd) do |stdin, stdout_err, wait_thr|
                    settings.demoPID = wait_thr[:pid]
                    while line = stdout_err.gets
                        puts "--> demo output: #{line}"
                    end
                    exit_status = wait_thr.value
                    if exit_status.success?
                        puts "#{cmd} running!"
                        settings.demoStarted = true
                    else
                        puts "#{cmd} failed!!!"
                        settings.demoStarted = false
                    end
                end
            rescue SignalException => e
                raise e
            rescue Exception => e
                puts "#{cmd} failed!!!"
                settings.demoStarted = false
            end
            settings.demoStarted = false
        end
        settings.demoStarted = true
    end

    def stop_demo
        begin
            puts "Stopping demo"
            Process.kill("TERM", settings.demoPID)
            Thread.kill(settings.demoThread)
        rescue SignalException => e
            raise e
        rescue Exception => e
            puts "No succes on exiting demo...!"
            settings.demoStarted = true
            return false
        end
        puts "demo exit success"
        settings.demoStarted = false
        return true
    end

end
