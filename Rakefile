require 'bundler/setup'
require 'bundler/gem_tasks'
require 'rake/testtask'
require 'yard'

task default: [:spec, :rubocop]

Rake::TestTask.new(:spec) do |spec|
  spec.loader = :direct
  spec.pattern = './spec/statsd_spec.rb'
  spec.verbose = true
end

namespace :build do
  YARD::Rake::YardocTask.new :doc
end

task :rubocop do
  sh "rubocop"
end
