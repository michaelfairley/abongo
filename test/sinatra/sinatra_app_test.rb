require 'sinatra_app'
require 'test/unit'
require 'rack/test'

ENV['RACK_ENV'] = 'test'

class SinatraAppTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_test1
    get '/test1'
    assert last_response.ok?
    assert last_response.body =~ /(a|b)/
  end
end