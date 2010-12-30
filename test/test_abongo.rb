require 'test/unit'
require 'rubygems'
require 'mongo'
require 'activesupport'
require 'lib/abongo'
require 'lib/abongo/experiment'
require 'lib/abongo/participant'


class TestAbongo < Test::Unit::TestCase

  def setup
    conn = Mongo::Connection.new
    db = conn['abongo_test']
    Abongo.db = db
    Abongo.options = {}
    Abongo.identity = nil
    Abongo.salt = 'Not really necessary.'
    Abongo.db['abongo_participants'].drop
    Abongo.db['alternatives'].drop
    Abongo.db['conversions'].drop
    Abongo.db['experiments'].drop
  end

  def teardown
  end

  def test_experiment_creation
    experiment = Abongo::Experiment.start_experiment!('test_test', ['alt1', 'alt2'])
    assert_equal(experiment['name'], 'test_test')
    assert_equal(experiment['alternatives'], ['alt1', 'alt2'])
    assert(Abongo::Experiment.tests_listening_to_conversion('test_test').include?(experiment['_id']))
  end

  def test_experiment_creation_occurs_once
    experiment1 = Abongo::Experiment.start_experiment!('test_test', ['alt1', 'alt2'])
    experiment2 = Abongo::Experiment.start_experiment!('test_test', ['alt1', 'alt2'])
    assert_equal(experiment1, experiment2)
  end

  def test_experiment_creation_with_conversion
    Abongo::Experiment.start_experiment!('test_test', ['alt1', 'alt2'], 'convert')
    experiment = Abongo::Experiment.get_test('test_test')
    assert_equal(experiment['name'], 'test_test')
    assert_equal(experiment['alternatives'], ['alt1', 'alt2'])
    assert(Abongo::Experiment.tests_listening_to_conversion('convert').include?(experiment['_id']))
  end

  def test_default_identity
    assert 0 <= Abongo.identity.to_i
    assert 10**10 >= Abongo.identity.to_i
  end

  def test_add_participation
    Abongo::Participant.add_participation('ident', 'test1')
    assert_equal(Abongo::Participant.find_participant('ident')['tests'], ['test1'])
    Abongo::Participant.add_participation('ident', 'test2')
    assert_equal(Abongo::Participant.find_participant('ident')['tests'], ['test1', 'test2'])
  end
  
  def test_add_conversions
    Abongo::Participant.add_conversion('ident', 'test1')
    assert_equal(Abongo::Participant.find_participant('ident')['conversions'], ['test1'])
    Abongo::Participant.add_conversion('ident', 'test2')
    assert_equal(Abongo::Participant.find_participant('ident')['conversions'], ['test1', 'test2'])
  end
    
  def test_find_alternative_for_user
    Abongo.identity = 'ident'
    experiment = Abongo::Experiment.start_experiment!('test_test', ['alt1', 'alt2'])
    assert_equal(Abongo.find_alternative_for_user('ident', experiment), 'alt1')
  end
  
  def test_test
    Abongo.identity = 'ident'
    assert_equal(Abongo.test('test_test', ['alt1', 'alt2']), 'alt1')
    experiment = Abongo::Experiment.get_test('test_test')
    assert_equal(experiment['name'], 'test_test')
    assert_equal(experiment['alternatives'], ['alt1', 'alt2'])
    assert_equal(Abongo::Participant.find_participant('ident')['tests'], [experiment['_id']])    
  end

  def test_test_with_block
    Abongo.identity = 'ident'
    Abongo.test('test_test', ['alt1', 'alt2']){|alt|
      assert_equal(alt, 'alt1')
    }
  end

  def test_flip
    Abongo.identity = 'ident'
    assert_equal(Abongo.flip('test_test'), true)
    experiment = Abongo::Experiment.get_test('test_test')
    assert_equal(experiment['name'], 'test_test')
    assert_equal(experiment['alternatives'], [true, false])
    assert_equal(Abongo::Participant.find_participant('ident')['tests'], [experiment['_id']])    
  end

  def test_flip_with_block
    Abongo.identity = 'ident'
    Abongo.flip('test_test'){|alt|
      assert_equal(alt, true)
    }
  end
  
  def test_test_short_circuit
    Abongo.identity = 'ident'
    assert_equal(Abongo.test('test_test', ['alt1', 'alt2']), 'alt1')
    Abongo::Experiment.end_experiment!('test_test', 'alt2')
    assert_equal(Abongo.test('test_test', ['alt1', 'alt2']), 'alt2')
    Abongo::Experiment.end_experiment!('test_test', 'alt3')
    assert_equal(Abongo.test('test_test', ['alt1', 'alt2']), 'alt3')
  end

  def test_ensure_one_participation_per_participant
    Abongo.identity = 'ident'
    10.times do
      Abongo.test('test_test', ['alt1', 'alt2'])
      participant = Abongo::Participant.find_participant('ident')
      assert_equal(participant['tests'].size, 1)
      alternative = Abongo.db['alternatives'].find_one(:test => participant['tests'].first, :content => 'alt1')
      assert_equal(alternative['participants'], 1)
    end
  end

  def test_ensure_multiple_participation
    Abongo.identity = 'ident'
    10.times do |num|
      Abongo.test('test_test', ['alt1', 'alt2'], {:multiple_participation => true})
      participant = Abongo::Participant.find_participant('ident')
      assert_equal(participant['tests'].size, 1)
      alternative = Abongo.db['alternatives'].find_one(:test => participant['tests'].first, :content => 'alt1')
      assert_equal(alternative['participants'], num+1)
    end
  end

  def test_score_conversion
    Abongo.identity = 'ident'
    Abongo.test('test_test', ['alt1', 'alt2'])
    participant = Abongo::Participant.find_participant('ident')
    alternative = Abongo.db['alternatives'].find_one(:test => participant['tests'].first, :content => 'alt1')
    assert_equal(alternative['participants'], 1)
    assert_equal(alternative['conversions'], 0)
    experiment = Abongo::Experiment.get_test('test_test')
    Abongo.score_conversion!(experiment['_id'])
    alternative = Abongo.db['alternatives'].find_one(:test => participant['tests'].first, :content => 'alt1')
    assert_equal(alternative['conversions'], 1)
  end

  def test_score_conversion_with_name
    Abongo.identity = 'ident'
    Abongo.test('test_test', ['alt1', 'alt2'])
    participant = Abongo::Participant.find_participant('ident')
    alternative = Abongo.db['alternatives'].find_one(:test => participant['tests'].first, :content => 'alt1')
    assert_equal(alternative['participants'], 1)
    assert_equal(alternative['conversions'], 0)
    experiment = Abongo::Experiment.get_test('test_test')
    Abongo.score_conversion!('test_test')
    alternative = Abongo.db['alternatives'].find_one(:test => participant['tests'].first, :content => 'alt1')
    assert_equal(alternative['conversions'], 1)
  end

  def test_score_conversion_only_once_per_participant
    Abongo.identity = 'ident'
    Abongo.test('test_test', ['alt1', 'alt2'])
    participant = Abongo::Participant.find_participant('ident')
    alternative = Abongo.db['alternatives'].find_one(:test => participant['tests'].first, :content => 'alt1')
    assert_equal(alternative['participants'], 1)
    assert_equal(alternative['conversions'], 0)
    experiment = Abongo::Experiment.get_test('test_test')
    10.times do
      Abongo.score_conversion!(experiment['_id'])
      alternative = Abongo.db['alternatives'].find_one(:test => participant['tests'].first, :content => 'alt1')
      assert_equal(alternative['conversions'], 1)
    end
  end

  def test_score_conversion_with_multiple_conversions
    Abongo.identity = 'ident'
    Abongo.options[:multiple_conversions] = true
    Abongo.test('test_test', ['alt1', 'alt2'])
    experiment = Abongo::Experiment.get_test('test_test')
    alternative = Abongo.db['alternatives'].find_one(:test => experiment["_id"], :content => 'alt1')
    assert_equal(alternative['participants'], 1)
    assert_equal(alternative['conversions'], 0)
    10.times do |num|
      Abongo.score_conversion!(experiment['_id'])
      alternative = Abongo.db['alternatives'].find_one(:test => experiment["_id"], :content => 'alt1')
      assert_equal(alternative['conversions'], num+1)
    end
  end

  def test_salt
    Abongo.identity = 'ident'
    assert_equal(Abongo.test('test_test', ['alt1', 'alt2']), 'alt1')
    Abongo.salt = "This will change the result"
    assert_equal(Abongo.test('test_test', ['alt1', 'alt2']), 'alt2')
  end
  
  def test_count_humans_only
    Abongo.identity = 'ident'
    Abongo.options[:count_humans_only] = true
    assert_equal("alt1", Abongo.test('test_test', ['alt1', 'alt2']))

    experiment = Abongo::Experiment.get_test('test_test')
    alternative = Abongo.db['alternatives'].find_one(:test => experiment['_id'], :content => 'alt1')
    assert_equal(alternative['participants'], 0)
    assert_equal(alternative['conversions'], 0)

    Abongo.score_conversion!('test_test')
    alternative = Abongo.db['alternatives'].find_one(:test => experiment['_id'], :content => 'alt1')
    assert_equal(alternative['participants'], 0)
    assert_equal(alternative['conversions'], 0)

    Abongo.human!
    alternative = Abongo.db['alternatives'].find_one(:test => experiment['_id'], :content => 'alt1')
    assert_equal(alternative['participants'], 1)
    assert_equal(alternative['conversions'], 1)


    assert_equal("alt1", Abongo.test('test2', ['alt1', 'alt2']))
    
    experiment = Abongo::Experiment.get_test('test2')
    alternative = Abongo.db['alternatives'].find_one(:test => experiment['_id'], :content => 'alt1')
    assert_equal(alternative['participants'], 1)
    assert_equal(alternative['conversions'], 0)

    Abongo.score_conversion!('test2')
    alternative = Abongo.db['alternatives'].find_one(:test => experiment['_id'], :content => 'alt1')
    assert_equal(alternative['participants'], 1)
    assert_equal(alternative['conversions'], 1)

    Abongo.human!
    alternative = Abongo.db['alternatives'].find_one(:test => experiment['_id'], :content => 'alt1')
    assert_equal(alternative['participants'], 1)
    assert_equal(alternative['conversions'], 1)
  end

  def test_parse_alternatives_array
    assert_equal([1, 5, 2, 4, true], Abongo.parse_alternatives([1, 5, 2, 4, true]))
  end

  def test_parse_alternatives_integer
    assert_equal([1, 2, 3, 4, 5], Abongo.parse_alternatives(5))
  end

  def test_parse_alternatives_range
    assert_equal([2, 3, 4, 5], Abongo.parse_alternatives(2..5))
  end

  def test_parse_alternatives_hash
    assert_equal(["three", "three", "three", "one"], Abongo.parse_alternatives({"three" => 3, "one" => 1}))
  end

  def test_parse_alternatives_hash_invalid_value
    assert_raise RuntimeError do
      Abongo.parse_alternatives({"three" => "bob"})
    end
  end

  def test_parse_alternatives_invalid_type
    assert_raise RuntimeError do
      Abongo.parse_alternatives(Abongo.new)
    end
  end

  def test_bongo_array
    Abongo.identity = 'ident'
    test1 = Abongo::Experiment.start_experiment!('test1', ['alt1', 'alt2'])
    test2 = Abongo::Experiment.start_experiment!('test2', ['alt1', 'alt2'])
    test3 = Abongo::Experiment.start_experiment!('test3', ['alt1', 'alt2'])
    test4 = Abongo::Experiment.start_experiment!('test3', ['alt1', 'alt2'])
    Abongo.test('test1', ['alt1', 'alt2'])
    Abongo.test('test2', ['alt1', 'alt2'])
    Abongo.test('test3', ['alt1', 'alt2'])
    assert_equal(0, Abongo.db['alternatives'].find_one({:content => Abongo.find_alternative_for_user(Abongo.identity, test1), :test => test1['_id']})['conversions'])
    assert_equal(0, Abongo.db['alternatives'].find_one({:content => Abongo.find_alternative_for_user(Abongo.identity, test2), :test => test2['_id']})['conversions'])
    assert_equal(0, Abongo.db['alternatives'].find_one({:content => Abongo.find_alternative_for_user(Abongo.identity, test3), :test => test3['_id']})['conversions'])
    assert_equal(0, Abongo.db['alternatives'].find_one({:content => Abongo.find_alternative_for_user(Abongo.identity, test4), :test => test4['_id']})['conversions'])

    Abongo.bongo!(['test1', 'test2'])
    assert_equal(1, Abongo.db['alternatives'].find_one({:content => Abongo.find_alternative_for_user(Abongo.identity, test1), :test => test1['_id']})['conversions'])
    assert_equal(1, Abongo.db['alternatives'].find_one({:content => Abongo.find_alternative_for_user(Abongo.identity, test2), :test => test2['_id']})['conversions'])
    assert_equal(0, Abongo.db['alternatives'].find_one({:content => Abongo.find_alternative_for_user(Abongo.identity, test3), :test => test3['_id']})['conversions'])
    assert_equal(0, Abongo.db['alternatives'].find_one({:content => Abongo.find_alternative_for_user(Abongo.identity, test4), :test => test4['_id']})['conversions'])
  end

  def test_bongo_nil
    Abongo.identity = 'ident'
    test1 = Abongo::Experiment.start_experiment!('test1', ['alt1', 'alt2'])
    test2 = Abongo::Experiment.start_experiment!('test2', ['alt1', 'alt2'])
    test3 = Abongo::Experiment.start_experiment!('test3', ['alt1', 'alt2'])
    Abongo.test('test1', ['alt1', 'alt2'])
    Abongo.test('test2', ['alt1', 'alt2'])
    assert_equal(0, Abongo.db['alternatives'].find_one({:content => Abongo.find_alternative_for_user(Abongo.identity, test1), :test => test1['_id']})['conversions'])
    assert_equal(0, Abongo.db['alternatives'].find_one({:content => Abongo.find_alternative_for_user(Abongo.identity, test2), :test => test2['_id']})['conversions'])
    assert_equal(0, Abongo.db['alternatives'].find_one({:content => Abongo.find_alternative_for_user(Abongo.identity, test3), :test => test3['_id']})['conversions'])

    Abongo.bongo!
    assert_equal(1, Abongo.db['alternatives'].find_one({:content => Abongo.find_alternative_for_user(Abongo.identity, test1), :test => test1['_id']})['conversions'])
    assert_equal(1, Abongo.db['alternatives'].find_one({:content => Abongo.find_alternative_for_user(Abongo.identity, test2), :test => test2['_id']})['conversions'])
    assert_equal(0, Abongo.db['alternatives'].find_one({:content => Abongo.find_alternative_for_user(Abongo.identity, test3), :test => test3['_id']})['conversions'])
  end

  def test_bongo_with_alternative_conversion
    Abongo.identity = 'ident'
    test1 = Abongo::Experiment.start_experiment!('test1', ['alt1', 'alt2'], "convert!")
    test2 = Abongo::Experiment.start_experiment!('test2', ['alt1', 'alt2'], "convert!")
    test3 = Abongo::Experiment.start_experiment!('test3', ['alt1', 'alt2'], "dontconvert!")
    Abongo.test('test1', ['alt1', 'alt2'])
    Abongo.test('test2', ['alt1', 'alt2'])
    assert_equal(0, Abongo.db['alternatives'].find_one({:content => Abongo.find_alternative_for_user(Abongo.identity, test1), :test => test1['_id']})['conversions'])
    assert_equal(0, Abongo.db['alternatives'].find_one({:content => Abongo.find_alternative_for_user(Abongo.identity, test2), :test => test2['_id']})['conversions'])
    assert_equal(0, Abongo.db['alternatives'].find_one({:content => Abongo.find_alternative_for_user(Abongo.identity, test3), :test => test3['_id']})['conversions'])

    Abongo.bongo!('convert!')
    assert_equal(1, Abongo.db['alternatives'].find_one({:content => Abongo.find_alternative_for_user(Abongo.identity, test1), :test => test1['_id']})['conversions'])
    assert_equal(1, Abongo.db['alternatives'].find_one({:content => Abongo.find_alternative_for_user(Abongo.identity, test2), :test => test2['_id']})['conversions'])
    assert_equal(0, Abongo.db['alternatives'].find_one({:content => Abongo.find_alternative_for_user(Abongo.identity, test3), :test => test3['_id']})['conversions'])
  end

  def test_bongo_with_test_name
    Abongo.identity = 'ident'
    test1 = Abongo::Experiment.start_experiment!('test1', ['alt1', 'alt2'])
    test2 = Abongo::Experiment.start_experiment!('test2', ['alt1', 'alt2'])
    test3 = Abongo::Experiment.start_experiment!('test3', ['alt1', 'alt2'])
    Abongo.test('test1', ['alt1', 'alt2'])
    Abongo.test('test2', ['alt1', 'alt2'])
    assert_equal(0, Abongo.db['alternatives'].find_one({:content => Abongo.find_alternative_for_user(Abongo.identity, test1), :test => test1['_id']})['conversions'])
    assert_equal(0, Abongo.db['alternatives'].find_one({:content => Abongo.find_alternative_for_user(Abongo.identity, test2), :test => test2['_id']})['conversions'])
    Abongo.bongo!('test1')
    assert_equal(1, Abongo.db['alternatives'].find_one({:content => Abongo.find_alternative_for_user(Abongo.identity, test1), :test => test1['_id']})['conversions'])
    assert_equal(0, Abongo.db['alternatives'].find_one({:content => Abongo.find_alternative_for_user(Abongo.identity, test2), :test => test2['_id']})['conversions'])
  end

  def test_bongo_doesnt_assume_participation
    Abongo.identity = 'ident'
    test1 = Abongo::Experiment.start_experiment!('test1', ['alt1', 'alt2'])
    Abongo.bongo!('test1')
    assert_equal(0, Abongo.db['alternatives'].find_one({:content => Abongo.find_alternative_for_user(Abongo.identity, test1), :test => test1['_id']})['conversions'])
    Abongo.test('test1', ['alt1', 'alt2'])
    assert_equal(0, Abongo.db['alternatives'].find_one({:content => Abongo.find_alternative_for_user(Abongo.identity, test1), :test => test1['_id']})['conversions'])
    Abongo.bongo!('test1')
    assert_equal(1, Abongo.db['alternatives'].find_one({:content => Abongo.find_alternative_for_user(Abongo.identity, test1), :test => test1['_id']})['conversions'])
  end

  def test_bongo_with_assume_participation
    Abongo.identity = 'ident'
    Abongo.options[:assume_participation] = true
    test1 = Abongo::Experiment.start_experiment!('test1', ['alt1', 'alt2'])
    assert_equal(0, Abongo.db['alternatives'].find_one({:content => Abongo.find_alternative_for_user(Abongo.identity, test1), :test => test1['_id']})['conversions'])
    Abongo.bongo!('test1')
    assert_equal(1, Abongo.db['alternatives'].find_one({:content => Abongo.find_alternative_for_user(Abongo.identity, test1), :test => test1['_id']})['conversions'])
    Abongo.test('test1', ['alt1', 'alt2'])
    assert_equal(1, Abongo.db['alternatives'].find_one({:content => Abongo.find_alternative_for_user(Abongo.identity, test1), :test => test1['_id']})['conversions'])
    Abongo.bongo!('test1')
    assert_equal(1, Abongo.db['alternatives'].find_one({:content => Abongo.find_alternative_for_user(Abongo.identity, test1), :test => test1['_id']})['conversions'])
  end
end
