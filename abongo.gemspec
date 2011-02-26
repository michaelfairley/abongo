# encoding: UTF-8
require File.expand_path('../lib/abongo/version', __FILE__)

Gem::Specification.new do |s|
  s.name               = 'abongo'
  s.homepage           = 'http://github.com/michaelfairley/abongo'
  s.summary            = 'Ruby A/B testing on MongoDB'
  s.require_path       = 'lib'
  s.authors            = ['Michael Fairley']
  s.email              = ['michaelfairley@gmail.com']
  s.version            = Abongo::VERSION
  s.files              = Dir.glob("{lib,test}/**/*") + %w[MIT-LICENSE README]
  s.license            = 'MIT'
  s.test_files         = Dir.glob('test/*.rb')

  s.add_dependency 'mongo'

  s.add_development_dependency 'rake'
end