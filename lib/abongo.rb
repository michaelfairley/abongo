class Abongo
  @@VERSION = '1.0.0'
  def self.VERSION; @@VERSION; end
  @@MAJOR_VERSION = '1.0'
  def self.MAJOR_VERSION; @@MAJOR_VERSION; end

  @@options ||= {}
  def self.options; @@options; end
  def self.options=(options); @@options = options; end

  @@salt = 'Not really necessary.'
  def self.salt; @@salt; end
  def self.salt=(salt); @@salt = salt; end

  def self.db; @@db; end
  def self.db=(db)
    @@db = db
    @@experiments = db['abongo_experiments']
    @@conversions = db['abongo_conversions']
    @@participants = db['abongo_participants']
    @@alternatives = db['abongo_alternatives']
  end

  def self.identity=(new_identity)
    @@identity = new_identity.to_s
  end

  def self.identity
    @@identity ||= rand(10 ** 10)
  end

  # TODO: add options
  def self.flip(test_name)
    if block_given?
      yield(self.test(test_name, [true, false]))
    else
      self.test(test_name, [true, false])
    end
  end

  def self.test(test_name, alternatives, options = {})
    # Test for short-circuit (the test has been ended)
    test = Abongo.get_test(test_name)
    return test['final'] unless test.nil? or test['final'].nil?

    # Create the test (if necessary)
    unless test
      conversion_name = options[:conversion] || options[:conversion_name]
      test = Abongo.start_experiment!(test_name, self.parse_alternatives(alternatives), conversion_name)
    end

    participant = Abongo.find_participant(Abongo.identity)
    choice = self.find_alternative_for_user(Abongo.identity, test)
    participating_tests = participant['tests']

    # TODO: Add expiriations
    # TODO: Pull participation add out
    if options[:multiple_participation] || !(participating_tests.include?(test['_id']))
      unless participating_tests.include?(test['_id'])
        Abongo.add_participation(identity, test['_id'])
      end
      
      # Small timing issue in here
      if (!@@options[:count_humans_only] || participant['human'])
        Abongo.alternatives.update({:content => choice, :test => test['_id']}, {:$inc => {:participants => 1}})
      end
    end

    if block_given?
      yield(choice)
    else
      choice
    end
  end

  def self.bongo!(name = nil, options = {})
    if name.kind_of? Array
      name.map do |single_test|
        self.bongo!(single_test, options)
      end
    else
      if name.nil?
        # Score all participating tests
        participant = Abongo.find_participant(Abongo.identity)
        participating_tests = participant['tests']
        participating_tests.each do |participating_test|
          self.bongo!(participating_test, options)
        end
      else # Could be a test name or conversion name
        tests_listening_to_conversion = Abongo.tests_listening_to_conversion(name)
        if tests_listening_to_conversion
          tests_listening_to_conversion.each do |test|
            self.score_conversion!(test)
          end
        else # No tests listening for this conversion. Assume it is just a test name
          self.score_conversion!(name)
        end
      end
    end
  end

  def self.score_conversion!(test_name)
    if test_name.kind_of? BSON::ObjectId
      participant = Abongo.find_participant(Abongo.identity)
      if options[:assume_participation] || participant['tests'].include?(test_name)
        if options[:multiple_conversions] || !participant['conversions'].include?(test_name)
          Abongo.add_conversion(Abongo.identity, test_name)
          if !options[:count_humans_only] || participant['human']
            test = Abongo.experiments.find_one(:_id => test_name)
            viewed_alternative = Abongo.find_alternative_for_user(Abongo.identity, test)
            Abongo.alternatives.update({:content => viewed_alternative, :test => test['_id']}, {'$inc' => {:conversions => 1}})
          end
        end
      end 
    else
      Abongo.score_conversion!(Abongo.get_test(test_name)['_id'])
    end
  end

  def self.participating_tests(only_current = true, identity = nil)
    identity ||= Abongo.identity
    participating_tests = (Abongo.participants.find_one({:identity => identity}) || {} )['tests']
    return {} if participating_tests.nil?
    tests_and_alternatives = participating_tests.inject({}) do |acc, test_id|
      test = Abongo.experiments.find_one(test_id)
      if !only_current or (test['final'].nil? or !test['final'])
        alternative = Abongo.find_alternative_for_user(identity, test)
        acc[test['name']] = alternative
      end
      acc
    end

    tests_and_alternatives
  end

  def self.human!(identity = nil)
    identity ||= Abongo.identity
    previous = Abongo.participants.find_and_modify({'query' => {:identity => identity}, 'update' => {'$set' => {:human => true}}, 'upsert' => true})
    
    unless previous['human']
      if previous['tests']
        previous['tests'].each do |test_id|
          test = Abongo.experiments.find_one(test_id)
          choice = Abongo.find_alternative_for_user(identity, test)
          Abongo.alternatives.update({:content => choice, :test => test['_id']}, {:$inc => {:participants => 1}})
        end
      end

      if previous['tests']
        previous['tests'].each do |test_id|
          test = Abongo.experiments.find_one(:_id => test_id)
          viewed_alternative = Abongo.find_alternative_for_user(identity, test)
          Abongo.alternatives.update({:content => viewed_alternative, :test => test['_id']}, {'$inc' => {:conversions => 1}})
        end
      end
    end
  end

  def self.end_experiment!(test_name, final_alternative, conversion_name = nil)
    warn("conversion_name is deprecated") if conversion_name
    Abongo.experiments.update({:name => test_name}, {:$set => { :final => final_alternative}}, :upsert => true, :safe => true)
  end

  protected
  def self.experiments; @@experiments; end
  def self.conversions; @@conversions; end
  def self.participants; @@participants; end
  def self.alternatives; @@alternatives; end

  def self.find_alternative_for_user(identity, test)
    test['alternatives'][self.modulo_choice(test['name'], test['alternatives'].size)]
  end

  def self.modulo_choice(test_name, choices_count)
    Digest::MD5.hexdigest(Abongo.salt.to_s + test_name + Abongo.identity.to_s).to_i(16) % choices_count
  end

  def self.parse_alternatives(alternatives)
    if alternatives.kind_of? Array
      return alternatives
    elsif alternatives.kind_of? Integer
      return (1..alternatives).to_a
    elsif alternatives.kind_of? Range
      return alternatives.to_a
    elsif alternatives.kind_of? Hash
      alternatives_array = []
      alternatives.each do |key, value|
        if value.kind_of? Integer
          alternatives_array += [key] * value
        else
          raise "You gave a hash with #{key} => #{value} as an element.  The value must be an integral weight."
        end
      end
      return alternatives_array
    else
      raise "I don't know how to turn [#{alternatives}] into an array of alternatives."
    end
  end
  
  def self.all_tests
    Abongo.experiments.find.to_a
  end

  def self.get_test(test_name)
    Abongo.experiments.find_one({:name => test_name}) || nil
  end

  def self.tests_listening_to_conversion(conversion)
    conversions = Abongo.conversions.find_one({:name => conversion})
    return nil unless conversions
    conversions['tests']
  end

  def self.start_experiment!(test_name, alternatives_array, conversion_name = nil)
    conversion_name ||= test_name

    Abongo.experiments.update({:name => test_name}, {:$set => { :alternatives => alternatives_array}}, :upsert => true, :safe => true)
    test = Abongo.experiments.find_one({:name => test_name})

    # This could be a lot more elegant
    cloned_alternatives_array = alternatives_array.clone
    while (cloned_alternatives_array.size > 0)
      alt = cloned_alternatives_array[0]
      weight = cloned_alternatives_array.size - (cloned_alternatives_array - [alt]).size
      Abongo.alternatives.update({:test => test['_id'], :content => alt}, {'$set' => {:weight => weight}, '$inc' => {:participants => 0, :conversions => 0}}, :upsert => true, :safe => true)
      cloned_alternatives_array -= [alt]
    end

    Abongo.conversions.update({'name' => conversion_name}, {'$addToSet' => { 'tests' => test['_id'] }}, :upsert => true, :safe => true)

    test
  end

  def self.find_participant(identity)
    {'identity' => identity, 'tests' => [], 'conversions' => [], 'human' => false}.merge(Abongo.participants.find_one({'identity' => identity})||{})
  end

  def self.add_conversion(identity, test_id)
    Abongo.participants.update({:identity => identity}, {'$addToSet' => {:conversions => test_id}}, :upsert => true, :safe => true)
  end

  def self.add_participation(identity, test_id)
    Abongo.participants.update({:identity => identity}, {'$addToSet' => {:tests => test_id}}, :upsert => true, :safe => true)
  end
end
