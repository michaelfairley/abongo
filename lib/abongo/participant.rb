class Abongo::Participant
  def self.find_participant(identity)
    {'identity' => identity, 'tests' => [], 'conversions' => [], 'human' => false}.merge(Abongo.db['abongo_participants'].find_one({'identity' => identity})||{})
  end

  def self.human!(identity)
    previous = Abongo.db['abongo_participants'].find_and_modify({'query' => {:identity => identity}, 'update' => {'$set' => {:human => true}}, 'upsert' => true})
    
    unless previous['human']
      if previous['tests']
        previous['tests'].each do |test_id|
          test = Abongo.db['experiments'].find_one(test_id)
          choice = Abongo.find_alternative_for_user(identity, test)
          Abongo.db['alternatives'].update({:content => choice, :test => test['_id']}, {:$inc => {:participants => 1}})
        end
      end

      if previous['tests']
        previous['tests'].each do |test_id|
          test = Abongo.db['experiments'].find_one(:_id => test_id)
          viewed_alternative = Abongo.find_alternative_for_user(identity, test)
          Abongo.db['alternatives'].update({:content => viewed_alternative, :test => test['_id']}, {'$inc' => {:conversions => 1}})
        end
      end
    end
  end

  def self.add_conversion(identity, test_id)
    Abongo.db['abongo_participants'].update({:identity => identity}, {'$addToSet' => {:conversions => test_id}}, :upsert => true, :safe => true)
  end

  def self.add_participation(identity, test_id)
    Abongo.db['abongo_participants'].update({:identity => identity}, {'$addToSet' => {:tests => test_id}}, :upsert => true, :safe => true)
  end
end
