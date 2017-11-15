require 'rubygems'
require 'rake/testtask'
require 'bundler'

task :default => :spec

Rake::TestTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.loader = :direct
  spec.pattern = './spec/statsd_spec.rb'
  spec.verbose = true
end

begin
  require 'yard'
rescue LoadError
else
  namespace :build do
    YARD::Rake::YardocTask.new :doc
  end
end

Bundler::GemHelper.install_tasks
