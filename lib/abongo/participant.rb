class Abongo::Participant
  # { identity: ..., tests : [experiments...] }

  def self.find_participant(identity)
    Abongo.db['abongo_participants'].find_one({'identity' => identity}) || {'identity' => identity, 'tests' => [], 'conversions' => []}
  end

  def self.is_human?(identity)
    
  end

  def self.add_conversion(identity, test_id)
    Abongo.db['abongo_participants'].update({:identity => identity}, {'$addToSet' => {:conversions => test_id}, "$pushAll" => {:tests => []}}, :upsert => true, :safe => true)
  end

  def self.add_participation(identity, test_id)
    Abongo.db['abongo_participants'].update({:identity => identity}, {'$addToSet' => {:tests => test_id}, "$pushAll" => {:conversions => []}}, :upsert => true, :safe => true)
  end
end
