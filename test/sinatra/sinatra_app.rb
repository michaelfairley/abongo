require 'rubygems'
require 'bundler/setup'
Bundler.require :default
require 'sinatra/abongo'

configure do
  Abongo.db = Mongo::Connection.new['sinatra']
end

get '/test1' do
  haml :test1
end
