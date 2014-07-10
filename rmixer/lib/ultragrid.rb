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
#  Authors:  Gerard Castillo <gerard.castillo@i2cat.net>,
#            Marc Palau <marc.palau@i2cat.net>
#
require 'socket'
require 'rest_client'

@@uv_cmd_priority_list = [  "uv -t testcard:640:480:15:UYVY-c libavcodec:codec=H.264 --rtsp-server", #first check if api control errors are working...
  "uv -t decklink:0:8 -c libavcodec:codec=H.264 --rtsp-server",
  "uv -t decklink:0:9 -c libavcodec:codec=H.264 --rtsp-server",
  "uv -t v4l2 -c libavcodec:codec=H.264 --rtsp-server",
  "uv -t testcard:1920:1080:20:UYVY -c libavcodec:codec=H.264 --rtsp-server",
  "uv -t testcard:640:480:15:UYVY -c libavcodec:codec=H.264 --rtsp-server"]
  
@hash_response 
  
def uv_check_and_tx(ip, port)
  if ip.eql?""
    ip="127.0.0.1"
  end

  ip_mixer = local_ip

  puts "\nTrying to set-up and transmit from #{ip_mixer} to mixer port #{port}\n"

  #first check uv availability (machine and ultragrid inside machine). Then proper configuration
  #1.- check decklink (fullHD, then HD)
  #2.- check v4l2
  #3.- check testcard
  #set working cmd by array (@uv_cmd) index
  begin
    response = RestClient.post "http://#{ip}/ultragrid/gui/check", :mode => 'local', :cmd => "uv -t testcard:640:480:15:UYVY -c libavcodec:codec=H.264 -P#{port}"
  rescue SignalException => e
    raise e
  rescue Exception => e
    puts "No connection to UltraGrid's machine or selected port in use! Please check far-end UltraGrid."
    return false
  end

  @@uv_cmd_priority_list.each { |cmd|
    replyCmd = "#{cmd} #{ip_mixer} -P#{port}"
    puts replyCmd
    begin
      response = RestClient.post "http://#{ip}/ultragrid/gui/check", :mode => 'local', :cmd => replyCmd
    rescue SignalException => e
      raise e
    rescue Exception => e
      puts "No connection to UltraGrid's machine!"
      return false
    end

    @hash_response = JSON.parse(response, :symbolize_names => true)

    if @hash_response[:checked_local]
      break if uv_run(ip,replyCmd)
    end
  }
  
  if @hash_response[:uv_running]
    return true
  end
  
  return false
end

def uv_run(ip, cmd)
  puts "running ultragrid with following configuration:"
  puts cmd
  begin
    response = RestClient.post "http://#{ip}/ultragrid/gui/run_uv_cmd", :cmd => cmd
  rescue SignalException => e
    raise e
  rescue Exception => e
    puts "No connection to UltraGrid's machine or selected port in use! Please check far-end UltraGrid."
    return false
  end
  @hash_response = JSON.parse(response, :symbolize_names => true)
  if @hash_response[:uv_running]
    puts "RUNNING!"
    return true
  end
  return false
end

def local_ip
  UDPSocket.open {|s| s.connect("64.233.187.99", 1); s.addr.last}
end
