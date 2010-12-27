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
    Abongo.db['abongo_participants'].drop
    Abongo.db['alternatives'].drop
    Abongo.db['conversions'].drop
    Abongo.db['experiments'].drop
  end

  def teardown
  end

  def test_experiment_creation
    Abongo::Experiment.start_experiment!('test_test', ['alt1', 'alt2'])
    experiment = Abongo::Experiment.get_test('test_test')
    assert_equal(experiment['name'], 'test_test')
    assert_equal(experiment['alternatives'], ['alt1', 'alt2'])
    assert(Abongo::Experiment.tests_listening_to_conversion('test_test').include?(experiment['_id']))
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

  end
  
  def test_test
    Abongo.identity = 'ident'
    assert_equal(Abongo.test('test_test', ['alt1', 'alt2']), 'alt1')
    experiment = Abongo::Experiment.get_test('test_test')
    assert_equal(experiment['name'], 'test_test')
    assert_equal(experiment['alternatives'], ['alt1', 'alt2'])
    assert_equal(Abongo::Participant.find_participant('ident')['tests'], [experiment['_id']])    
    assert_equal(Abongo.find_alternative_for_user(experiment), 'alt1')
  end

  def test_test_with_block
    Abongo.identity = 'ident'
    Abongo.test('test_test', ['alt1', 'alt2']){|alt|
      assert_equal(alt, 'alt1')
    }
  end
  
  def test_test_short_circuit

  end
end
