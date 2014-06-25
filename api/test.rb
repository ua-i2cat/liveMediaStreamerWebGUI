ENV['RACK_ENV'] = 'test'

require './api'
require 'test/unit'
require 'rack/test'
require 'json'

class MixerAPITest < Test::Unit::TestCase

  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  # def test_start_ok
  #   post '/start'
  #   puts last_response.body
  #   assert last_response.ok?
  # end



  def add_stream
    post '/streams/add', :size => "1024x436"
    assert last_response.ok?
  end

  def test_add_and_remove_stream_ok
    get '/streams'
    assert last_response.ok?
    before = JSON.parse(last_response.body, :symbolize_names => true)
    post '/streams/add', :size => "1024x436"
    assert last_response.ok?
    get '/streams'
    assert last_response.ok?
    after = JSON.parse(last_response.body, :symbolize_names => true)
    found = nil
    after.each do |s|
      if s[:width] == 1024 && s[:height] == 436
        found = s
      end
    end
    assert found
    post "/streams/#{found[:id]}/remove"
    assert last_response.ok?
    final = JSON.parse(last_response.body, :symbolize_names => true)
    assert !final.include?(found)
  end

  def test_add_and_remove_destination_ok
    get '/destinations'
    assert last_response.ok?
    before = JSON.parse(last_response.body, :symbolize_names => true)
    post '/destinations/add',
      :ip => '192.168.10.217',
      :port => 8000
    assert last_response.ok?
    get '/destinations'
    assert last_response.ok?
    after = JSON.parse(last_response.body, :symbolize_names => true)
    found = nil
    after.each do |d|
      if d[:ip] == '192.168.10.217' && d[:port] == 8000
        found = d
      end
    end
    assert found
    post "/destinations/#{found[:id]}/remove"
    assert last_response.ok?
    final = JSON.parse(last_response.body, :symbolize_names => true)
    assert !final.include?(found)
  end

end
