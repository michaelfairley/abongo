require 'rake'
require 'rake/testtask'
require File.expand_path('../lib/abongo/version', __FILE__)

desc 'Default: run unit tests.'
task :default => :test_all

task :test_all => :test do
  %w[rails2 rails3].each do |dir|
    sh <<-CMD
      cd test/#{dir}
      BUNDLE_GEMFILE=Gemfile bundle exec rake test
    CMD
  end
end

desc 'Test the A/Bongo plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.libs << 'test'
  t.test_files = Dir.glob('test/test_*.rb')
  t.verbose = true
end

desc 'Builds the gem'
task :build do
  sh "gem build abongo.gemspec"
end

desc 'Builds and installs the gem'
task :install => :build do
  sh "gem install abongo-#{Abongo::VERSION}"
end

desc 'Tags version, pushes to remote, and pushes gem'
task :release => :build do
  sh "git tag v#{Abongo::VERSION}"
  sh "git push origin master"
  sh "git push origin v#{Abongo::VERSION}"
  sh "gem push abongo-#{Abongo::VERSION}.gem"
end
