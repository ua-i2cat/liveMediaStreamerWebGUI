require 'test/unit'
require 'json'
require 'rmixer'

class TestConnectorBasic < Test::Unit::TestCase

  def setup
    @connector = RMixer::Connector.new(
      'localhost', 2222, testing = :request
      )
  end

  def teardown
    @connector.exit
  end

  def test_start_request
    request = @connector.start
    assert_equal("start_mixer", request[:action])
    assert_not_nil(request[:params][:width])
    assert_not_nil(request[:params][:height])
    assert_not_nil(request[:params][:max_streams])
    assert_not_nil(request[:params][:input_port])
  end

  def test_add_stream_request
    request = @connector.add_stream(1024, 436)
    assert_equal("add_stream", request[:action])
    assert_equal(1024, request[:params][:width])
    assert_equal(436, request[:params][:height])
  end

  def test_remove_stream_request
    id = Random.rand(8)
    request = @connector.remove_stream(id)
    assert_equal("remove_stream", request[:action])
    assert_equal(id, request[:params][:id])
  end

  def test_modify_stream_request
    id = Random.rand(8)
    request = @connector.modify_stream(id, 400, 400, options = {
      :x => 10,
      :y => 10,
      :layer => 1,
      :keep_aspect_ratio => true
      })
    assert_equal("modify_stream", request[:action])
    assert_equal(id, request[:params][:id])
    assert_equal(400, request[:params][:width])
    assert_equal(400, request[:params][:height])
    assert_equal(10, request[:params][:x])
    assert_equal(10, request[:params][:y])
    assert_equal(1, request[:params][:layer])
    assert_equal(true, request[:params][:keep_aspect_ratio])
  end

  def test_disable_stream_request
    id = Random.rand(8)
    request = @connector.disable_stream(id)
    assert_equal("disable_stream", request[:action])
    assert_equal(id, request[:params][:id])
  end

  def test_enable_stream_request
    id = Random.rand(8)
    request = @connector.enable_stream(id)
    assert_equal("enable_stream", request[:action])
    assert_equal(id, request[:params][:id])
  end

  def test_modify_layout_request
    request = @connector.modify_layout(1200, 1000, false)
    assert_equal("modify_layout", request[:action])
    assert_equal(1200, request[:params][:width])
    assert_equal(1000, request[:params][:height])
    assert_equal(false, request[:params][:resize_streams])
  end

  def test_add_destination_request
    request = @connector.add_destination("localhost", 8000)
    assert_equal("add_destination", request[:action])
    assert_equal("localhost", request[:params][:ip])
    assert_equal(8000, request[:params][:port])
  end

  def test_remove_destination_request
    id = Random.rand(8)
    request = @connector.remove_destination(id)
    assert_equal("remove_destination", request[:action])
    assert_equal(id, request[:params][:id])
  end

  def test_stop_request
    request = @connector.stop
    assert_equal("stop_mixer", request[:action])
  end

  def test_exit_request
    request = @connector.exit
    assert_equal("exit_mixer", request[:action])
  end

  def test_get_streams_request
    request = @connector.get_streams
    assert_equal("get_streams", request[:action])
  end

  def test_get_stream_request
    id = Random.rand(8)
    request = @connector.get_stream(id)
    assert_equal("get_stream", request[:action])
    assert_equal(id, request[:params][:id])
  end

  def test_get_destinations_request
    request = @connector.get_destinations
    assert_equal("get_destinations", request[:action])
  end

  def test_get_destination_request
    id = Random.rand(8)
    request = @connector.get_destination(id)
    assert_equal("get_destination", request[:action])
    assert_equal(id, request[:params][:id])
  end

  def test_get_layout_request
    request = @connector.get_layout
    assert_equal("get_layout", request[:action])
  end

end 