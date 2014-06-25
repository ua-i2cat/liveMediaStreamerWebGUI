#!/usr/bin/ruby

require 'objspace'

def test_func(pipe)
    pipe << {:test_pipe => "teeeeeest"}
end

a_streams1 =
{:audio_input_streams => [
    {:id => 1, :bps => 2},
    {:id => 3, :bps => 2}
  ]
}
a_streams2 =
  {:audio_output_streams => [
    {:id => 2, :bps => 2},
    {:id => 4, :bps => 2}
  ]
}


pipe = []

pipe << a_streams1
puts pipe
pipe << a_streams2
puts pipe
test_func(pipe)
puts pipe


pipe.each do |s|
    puts "Pipe position"
    puts s
end

ret = ObjectSpace.memsize_of(pipe)
puts ret

