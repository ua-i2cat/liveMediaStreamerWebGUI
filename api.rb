
get '/' do
    redirect '/app'
  end

  get '/app' do
    redirect '/app/mixer'
  end

  get '/app/mixer' do
    content_type :html
    dashboard
  end

  post '/app/channel/:id/mute' do
    content_type :html
    error_html do
      settings.mixer.channel_mute(params[:id].to_i)
    end
    redirect '/app'
  end

  post '/app/channel/:id/solo' do
    content_type :html
    error_html do
      settings.mixer.channel_solo(params[:id].to_i)
    end
    redirect '/app'
  end

  post '/app/channel/:id/change_volume' do
    content_type :html
    error_html do
      settings.mixer.channel_change_volume(params[:id].to_i, params[:volume].to_f)
    end
    redirect '/app'
  end
  
  post '/app/channel/master/mute' do
    content_type :html
    error_html do
      settings.mixer.master_mute(params[:id].to_i)
    end
    redirect '/app'
  end

  post '/app/channel/master/change_volume' do
    content_type :html
    error_html do
      settings.mixer.master_change_volume(params[:volume].to_f)
    end
    redirect '/app'
  end

  post '/app/config_output' do
    content_type :html
    error_html do
      settings.mixer.config_output(params[:codec], params[:sample_rate], params[:bps], params[:channels])
    end
    redirect '/app'
  end

  post '/app/channel/add' do
    content_type :html
    error_html do
      settings.mixer.add_channel(params[:codec], params[:sample_rate], params[:bps], params[:channels])
    end
    redirect '/app'
  end

 