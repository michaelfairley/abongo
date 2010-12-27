class Abongo::Experiment
  # {'name': 'alternatives': [...], 'participants': ..., 'alternatives': ..., final: ...}
  def self.all_tests
    Abongo.db['experiments'].find.to_a
  end

  #def self.get_alternatives(test)
  #  Abongo.db['alternatives'].find({:test => test['_id']}).to_a
  #end

  def self.get_test(test_name)
    Abongo.db['experiments'].find_one({:name => test_name}) || nil
  end

  def self.tests_listening_to_conversion(conversion)
    conversions = Abongo.db['conversions'].find_one({:name => conversion})
    return nil unless conversions
    conversions['tests']
  end

  def self.start_experiment!(test_name, alternatives_array, conversion_name = nil)
    conversion_name ||= test_name

    Abongo.db['experiments'].update({:name => test_name}, {:$set => { :alternatives => alternatives_array}}, :upsert => true, :safe => true)
    test = Abongo.db['experiments'].find_one({:name => test_name})

    # This could be a lot more elegant
    cloned_alternatives_array = alternatives_array.clone
    while (cloned_alternatives_array.size > 0)
      alt = cloned_alternatives_array[0]
      weight = cloned_alternatives_array.size - (cloned_alternatives_array - [alt]).size
      Abongo.db['alternatives'].update({:test => test['_id'], :content => alt}, {'$set' => {:weight => weight}, '$inc' => {:participants => 0, :conversions => 0}}, :upsert => true, :safe => true)
      cloned_alternatives_array -= [alt]
    end

    Abongo.db['conversions'].update({'name' => conversion_name}, {'$addToSet' => { 'tests' => test['_id'] }}, :upsert => true, :safe => true)

    test
  end

  def self.end_experiment!(test_name, final_alternative, conversion_name = nil)
    warn("conversion_name is deprecated") if conversion_name
    Abongo.db['experiments'].update({:name => test_name}, {:$set => { :final => final_alternative}}, :upsert => true, :safe => true)
  end
end
