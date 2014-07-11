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

require 'rubygems'
require 'bundler/setup'

require 'liquid'
require 'sinatra/base'
require 'rmixer'

class MixerAPI < Sinatra::Base

  set :ip, '127.0.0.1'
  set :port, 7777
  set :mixer, RMixer::Mixer.new(settings.ip, settings.port)

  def error_html
    begin
      yield
    rescue Errno::ECONNREFUSED, RMixer::MixerError => e
      status 500
      halt liquid :error, :locals => { "message" => e.message }
    end
  end

  helpers do
    def started
      error_html do
        settings.mixer.isStarted
      end
    end
    def isNumber?(object)
      true if Float(object) rescue false
    end
  end

  def dashboardExtra (id = "videoMixer")
    settings.mixer.updateDataBase

    if started
     
      if (id == "audioMixer")
        mixerHash = settings.mixer.getAudioMixerState
        liquid :audioMixer, :locals => {
            "stateHash" => mixerHash
          }
      elsif (id == "videoMixer")
        mixerHash = settings.mixer.getAudioMixerState
        liquid :videoMixer, :locals => {
            "stateHash" => mixerHash
          }
      end
    
    else
      liquid :before
    end

  end

  def dashboardVideo (grid = '2x2')

    if started
      mixerHash = settings.mixer.getVideoMixerState(grid)
      liquid :videoMixer, :locals => {
          "stateHash" => mixerHash
        }
    else
      liquid :before
    end
  end

   def dashboardAudio
    settings.mixer.updateDataBase

    if started
      mixerHash = settings.mixer.getAudioMixerState
      liquid :audioMixer, :locals => {
          "stateHash" => mixerHash
        }
    else
      liquid :before
    end
  end

  # Web App Methods

  get '/' do
    redirect '/app'
  end

  get '/app' do
    redirect '/app/audiomixer'
  end

  post '/app/start' do
    content_type :html
    error_html do
      settings.mixer.start
    end
    redirect '/app'
  end

  get '/app/audiomixer' do
    content_type :html
    dashboardAudio
  end

  get '/app/videomixer' do
    redirect '/app/videomixer/grid2x2'
  end

  get '/app/videomixer/grid2x2' do
    content_type :html
    dashboardVideo('2x2')
  end

  get '/app/videomixer/grid3x3' do
    content_type :html
    dashboardVideo('3x3')
  end

  get '/app/videomixer/grid4x4' do
    content_type :html
    dashboardVideo('4x4')
  end

   get '/app/videomixer/gridPiP' do
    content_type :html
    dashboardVideo('PiP')
  end

   get '/app/mixer' do
    content_type :html
    dashboardExtra("videoMixer")
  end

  post '/app/audiomixer/:mixerid/channel/:channelid/mute' do
    content_type :html
    error_html do
      if (params[:channelid] == "master")
        settings.mixer.sendRequest(
          settings.mixer.muteMaster(params[:mixerid].to_i)
        )
      else
        settings.mixer.sendRequest(
          settings.mixer.muteChannel(params[:mixerid].to_i, params[:channelid].to_i)
        )
      end
    end
    redirect '/app/audiomixer'
  end

  post '/app/audiomixer/:mixerid/channel/:channelid/solo' do
    content_type :html
    error_html do
      settings.mixer.sendRequest(
        settings.mixer.soloChannel(params[:mixerid].to_i, params[:channelid].to_i)
      )
    end
    redirect '/app/audiomixer'
  end

  post '/app/audiomixer/:mixerid/channel/:channelid/changeVolume' do
    content_type :html
    error_html do
      if (params[:channelid] == "master")
        settings.mixer.sendRequest(
          settings.mixer.changeMasterVolume(params[:mixerid].to_i, params[:volume].to_f)
        )
      else
        settings.mixer.sendRequest(
          settings.mixer.changeChannelVolume(params[:mixerid].to_i, params[:channelid].to_i, params[:volume].to_f)
        )
      end
    end
    redirect '/app/audiomixer'
  end
  
  post '/app/audiomixer/:mixer_id/:encoder_id/reconfigure' do
    content_type :html
    error_html do
      puts params
      settings.mixer.configEncoder(params[:encoder_id].to_i, 
                                   params[:codec], 
                                   params[:sampleRate].to_i, 
                                   params[:channels].to_i
                                  )
    end
    redirect '/app/audiomixer'
  end

  post '/app/audiomixer/:mixerID/addSession' do
    content_type :html
    error_html do
      settings.mixer.addRTPSession(0, "a",
                                   params[:port].to_i,
                                   "audio", 
                                   params[:codec], 
                                   5000, 
                                   params[:sampleRate].to_i, 
                                   params[:channels].to_i
                                  )
    end
    redirect '/app/audiomixer'
  end

   post '/app/audiomixer/:mixerID/addOutputSession' do
    content_type :html
    error_html do
      settings.mixer.addOutputSession(params[:mixerID].to_i, params[:sessionName])
    end
    redirect '/app/audiomixer'
  end

  post '/app/videoMixer/:grid/applyGrid' do
    content_type :html
    error_html do
      positions = []
      params.each do |k,v|
        if isNumber?(k)
          pos = {
            :pos => k.to_i,
            :ch => v.to_i
          }
          positions << pos
        end
      end

      settings.mixer.applyGrid(params[:grid], positions)

    end
    redirect "/app/videomixer/grid#{params[:grid]}"
  end

  post '/app/videoMixer/:channel/addSession' do
    content_type :html
    error_html do
      settings.mixer.addRTPSession(params[:channel].to_i,
                                   params[:sourceIP],
                                   params[:sourceType],
                                   params[:port].to_i,
                                   "video", 
                                   params[:codec], 
                                   5000, 
                                   90000
                                  )
    end
    redirect '/app/videomixer'
  end
  
  post '/app/videoMixer/:channel/set_input_size' do
    content_type :html
    error_html do
      settings.mixer.updateInputChannelSize(params[:channel].to_i,
                                              params[:size]
                                              )
    end
    redirect '/app/videomixer'
  end
  
  post '/app/videoMixer/:channel/set_input_fps' do
    content_type :html
    error_html do
      settings.mixer.updateInputChannelFPS(params[:channel].to_i,
                                              params[:fps]
                                              )
    end
    redirect '/app/videomixer'
  end
  
  post '/app/videoMixer/:channel/set_input_br' do
    content_type :html
    error_html do
      settings.mixer.updateInputChannelBitRate(params[:channel].to_i,
                                              params[:br]
                                              )
    end
    redirect '/app/videomixer'
  end
  
  post '/app/videoMixer/:channel/set_input_vbcc' do
    content_type :html
    error_html do
      puts params
      settings.mixer.updateInputChannelVBCC(params[:channel].to_i,
                                              params[:vbcc]
                                              )
    end
    redirect '/app/videomixer'
  end
  
  #TODO
  #gets channel index (not port) to be removed from sessions
  post '/app/videoMixer/:channel/rmSession' do
    content_type :html
    error_html do
      settings.mixer.rmRTPSession(params[:channel].to_i,
                                  params[:port].to_i,
                                  "video",
                                  params[:codec],
                                  5000,
                                  90000
                                  )
    end
    redirect '/app/videomixer'
  end

  post '/app/videoMixer/:channel/commute' do
    content_type :html
    error_html do
      settings.mixer.commute(params[:channel].to_i)
    end
    redirect '/app/videomixer'
  end

  post '/app/videoMixer/:channel/fade/:time' do
    content_type :html
    error_html do
      settings.mixer.fade(params[:channel].to_i, params[:time].to_i)
    end
    redirect '/app/videomixer'
  end
end
