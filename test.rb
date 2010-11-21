require 'rubygems'
require 'activesupport'
require 'mongo'
require 'lib/abongo'
require 'lib/abongo/experiment'
require 'lib/abongo/participants'

conn = Mongo::Connection.new
db = conn['test']
Abongo.db = db

Abongo.db['abongo_participants'].drop
Abongo.db['alternatives'].drop
Abongo.db['conversions'].drop
Abongo.db['experiments'].drop

10.times{|t|
  Abongo.identity = t.to_s
  puts "#{Abongo.test("t1", ["a1", "a2"])} #{Abongo.test("t2", ["a1", "a2"])}"
  if t <= 4
    Abongo.bongo!("t1")
  else
    Abongo.bongo!("t2")
  end

}

Abongo::Experiment.all_tests.each{|test|
  puts test['name']
  Abongo::Experiment.get_alternatives(test).each{|alt|
    puts "  #{alt['content']} #{alt['participants']} #{alt['conversion']}"
  }
}
