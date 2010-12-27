class Abongo::Participant
  # { identity: ..., tests : [experiments...] }

  def self.find_participant(identity)
    Abongo.db['abongo_participants'].find_one({'identity' => identity}) || {'identity' => identity, 'tests' => [], 'conversions' => []}
  end

  def self.is_human?(identity)
    
  end

  def self.add_conversion(identity, test_name)
    Abongo.db['abongo_participants'].update({:identity => identity}, {'$addToSet' => {:conversions => test_name}, "$pushAll" => {:tests => []}}, :upsert => true)
  end

  def self.add_participation(identity, test_name)
    Abongo.db['abongo_participants'].update({:identity => identity}, {'$addToSet' => {:tests => test_name}, "$pushAll" => {:conversions => []}}, :upsert => true)
  end
end
