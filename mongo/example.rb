require 'mongo'

include Mongo

host = ENV['MONGO_RUBY_DRIVER_HOST'] || 'localhost'
port = ENV['MONGO_RUBY_DRIVER_PORT'] || MongoClient::DEFAULT_PORT

puts "Connecting to #{host}:#{port}"
db = MongoClient.new(host, port).db('ruby-mongo-examples')
paths = db.collection('paths')
filters = db.collection('filters')

paths.remove
filters.remove

stateHash = 
{:filters=>
  [{:id=>846930886, :type=>"transmitter"},
   {:id=>1111111, :type=>"transmitter"},
   {:id=>900056138, :type=>"audioEncoder", :codec=>"opus", :sampleRate=>48000, :channels=>2, :sampleFormat=>"s16p"},
   {:id=>1804289383, :type=>"receiver"},
   {:id=>2058779693, :type=>"audioMixer", :sampleRate=>48000, :channels=>2, :sampleFormat=>"s16p", :gains=>[]}],
 :paths=>[{:id=>299802429, :originFilter=>2058779693, :destinationFilter=>846930886, :originWriter=>1, :destinationReader=>37871390, :filters=>[900056138]}]
}

stateHash[:filters].each do |h|
    filters.insert(h)
end


# newFilter = {:id => 11111, :type => "audioMixer"}
# filters.insert(newFilter)

# puts filters.find.each { |doc| puts doc.inspect }


filter = filters.find(:type=>"transmitter")
filter.each { |f| puts f}
#filter[:gains] = []  
#filter[:gains] << {:id => 21212, :gain => 0.3}
#filters.update( {:type=>"audioMixer"}, filter )

#puts filters.find.each { |doc| puts doc.inspect }
