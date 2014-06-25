Mixer Web API / Sinatra
=======================

Installation
------------

    $ bundle install

Running
-------

- Locally (development)

    $ rackup

- With unicorn: configure the application with `unicorn.rb`. To run locally:
    
    $ mkdir tmp
    $ mkdir tmp/pids tmp/sockets
    $ mkdir log
    $ unicorn -c unicorn.rb --port 8080 [... options ...]
