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

  def dashboardExtra (id = "videoMixer")
    settings.mixer.updateDataBase

    if (id == "audioMixer")
      mixerHash = settings.mixer.getAudioMixerState
      liquid :audioMixer, :locals => {
          "stateHash" => mixerHash
        }
    elsif (id == "videoMixer")
      #mixerHash = settings.mixer.getAudioMixerState
      liquid :videoMixer, :locals => {
          "stateHash" => mixerHash
        }
    end
  end

  def dashboardVideo (grid = 'grid2x2')
    mixerHash = settings.mixer.getVideoMixerState
  end

  def dashboard (id = 1)
    k2s =
    lambda do |h|
      Hash === h ?
        Hash[
          h.map do |k, v|
            [k.respond_to?(:to_s) ? k.to_s : k, k2s[v]]
          end
        ] : h
    end

    if started
      
      #Input streams json parsing
      i_streams = settings.mixer.input_streams
      input_streams = []
      
      i_streams.each do |s|
        crops = []
        s[:crops].each do |c|
          crops << k2s[c]
        end
        s[:crops] = crops
        input_streams << k2s[s]
      end

      #Output stream json parsing
      o_stream = settings.mixer.output_stream
      output_stream = []
      o_crops = []

      o_stream[:crops].each do |c|
        dst = []
        c[:destinations].each do |d|
          dst << k2s[d]
        end
        c[:destinations] = dst
        o_crops << k2s[c]
      end

      o_stream[:crops] = o_crops
      output_stream << k2s[o_stream]

      #Stats json parsing
      hash_stats = settings.mixer.get_stats
      i_stats, o_stats = [], []

    if hash_stats[:input_streams] != nil
      hash_stats[:input_streams].each do |s|
        i_stats << k2s[s]
      end
      hash_stats[:input_streams] = i_stats
    end
      
    if hash_stats[:output_streams] != nil
      hash_stats[:output_streams].each do |s|
        o_stats << k2s[s]
      end
      hash_stats[:output_streams] = o_stats
    end

      if (id == 2)
        liquid :commute, :locals => {
          "input_streams" => input_streams,
          "fade_time" =>settings.fade_time
        }
      elsif (id == 3)
        liquid :stats, :locals => {
          "input_stats" => i_stats,
          "output_stats" => o_stats
        }
      else
        liquid :index, :locals => {
          "input_streams" => input_streams,
          "output_streams" => output_stream,
          "grid" => settings.grid,
          "output_grid" => settings.output_grid
        }
      end
    else
      liquid :before
    end
  end

  # Web App Methods

  get '/' do
    redirect '/app'
  end

  get '/app' do
    redirect '/app/videomixer'
  end

  get '/app/videomixer' do
    redirect '/app/videomixer/grid2x2'
  end

  get '/app/videomixer/grid2x2' do
    content_type :html
    dashboardVideo('grid2x2')
  end

  get '/app/videomixer/grid3x3' do
    content_type :html
    dashboardVideo('grid3x3')
  end

  get '/app/videomixer/grid4x4' do
    content_type :html
    dashboardVideo('grid4x4')
  end

   get '/app/mixer' do
    content_type :html
    dashboardExtra("videoMixer")
  end

  post '/app/:mixerid/channel/:channelid/mute' do
    content_type :html
    error_html do
      if (params[:channelid] == "master")
        settings.mixer.muteMaster(params[:mixerid].to_i)
      else
        settings.mixer.muteChannel(params[:mixerid].to_i, params[:channelid].to_i)
      end
    end
    redirect '/app'
  end

  post '/app/:mixerid/channel/:channelid/solo' do
    content_type :html
    error_html do
      settings.mixer.soloChannel(params[:mixerid].to_i, params[:channelid].to_i)
    end
    redirect '/app'
  end

  post '/app/:mixerid/channel/:channelid/changeVolume' do
    content_type :html
    error_html do
      if (params[:channelid] == "master")
        settings.mixer.changeMasterVolume(params[:mixerid].to_i, params[:volume].to_f)
      else
        settings.mixer.changeChannelVolume(params[:mixerid].to_i, params[:channelid].to_i, params[:volume].to_f)
      end
    end
    redirect '/app'
  end
  
  post '/app/:mixer_id/:encoder_id/reconfigure' do
    content_type :html
    error_html do
      puts params
      settings.mixer.configEncoder(params[:encoder_id].to_i, 
                                   params[:codec], 
                                   params[:sampleRate].to_i, 
                                   params[:channels].to_i
                                  )
    end
    redirect '/app'
  end

  post '/app/:mixerID/addSession' do
    content_type :html
    error_html do
      settings.mixer.addRTPSession(settings.mixer.getReceiverID, 
                                   params[:port].to_i,
                                   "audio", 
                                   params[:codec], 
                                   5000, 
                                   params[:sampleRate].to_i, 
                                   params[:channels].to_i
                                  )
    end
    redirect '/app'
  end

   post '/app/:mixerID/addOutputSession' do
    content_type :html
    error_html do
      settings.mixer.addOutputSession(params[:mixerID].to_i, params[:sessionName])
    end
    redirect '/app'
  end

end
