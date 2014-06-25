require 'rubygems'
require 'sinatra'
require 'liquid'

set :grid, 1

get '/' do
  liquid :index, :locals => { 'streams' => [{
	'id' => 1, 
	'orig_w' => 1024, 
	'orig_h' => 436, 
	'width' => 1280, 
	'height' => 720, 
	'x' => 100, 
	'y' => 100, 
	'layer' => 2,  
	'panel_type' => 'panel-success', 
	'button_type' => 'btn-warning', 
	'button_text' => 'Disable'
	},
	{
	'id' => 2, 
	'orig_w' => 1920, 
	'orig_h' => 1080, 
	'width' => 640, 
	'height' => 360, 
	'x' => 200, 
	'y' => 200, 
	'layer' => 3,  
	'panel_type' => 'panel-warning', 
	'button_type' => 'btn-success', 
	'button_text' => 'Enable'
	},
	{
	'id' => 2, 
	'orig_w' => 1920, 
	'orig_h' => 1080, 
	'width' => 640, 
	'height' => 360, 
	'x' => 200, 
	'y' => 200, 
	'layer' => 3,  
	'panel_type' => 'panel-warning', 
	'button_type' => 'btn-success', 
	'button_text' => 'Enable'
	},
	{
	'id' => 2, 
	'orig_w' => 1920, 
	'orig_h' => 1080, 
	'width' => 640, 
	'height' => 360, 
	'x' => 200, 
	'y' => 200, 
	'layer' => 3,  
	'panel_type' => 'panel-warning', 
	'button_type' => 'btn-success', 
	'button_text' => 'Enable'
}],
'destinations' => [{
	'id' => 1,
	'ip' => '192.168.10.134',
	'port' => 5004
	},
	{
	'id' => 1,
	'ip' => '192.168.10.134',
	'port' => 5004
	},
	{
	'id' => 2,
	'ip' => '192.168.10.217',
	'port' => 8000
}] }
end


