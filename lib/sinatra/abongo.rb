require 'sinatra/base'

module Sinatra
  module Abongo
    def ab_test(test_name, alternatives = nil, options = {}, &block)
      ::Abongo.test(test_name, alternatives, options)
    end
  end

  helpers Abongo
end