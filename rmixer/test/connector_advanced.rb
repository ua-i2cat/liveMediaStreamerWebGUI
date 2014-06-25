require 'test/unit'
require 'json'
require_relative '../rmixer/connector'
require './server'


class TestConnectorAdvanced < Test::Unit::TestCase

  def setup
    @server = MockServer.new 'localhost', 8888
    @server.start
    sleep 1
    @connector = RMixer::Connector.new 'localhost', 8888
  end

  def teardown
    @server.stop
  end

  def test_basic
    assert_equal(true, @connector.get_stream(0))
  end

  def test_get_streams
    response = @connector.get_streams
    assert_equal(true, response)
  end

end