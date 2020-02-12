require 'bundler/setup'
require 'bundler/gem_tasks'
require 'rake/testtask'
require 'yard'

task default: [:test, :rubocop]

Rake::TestTask.new(:test) do |test|
  test.loader = :direct
  test.pattern = './test/statsd_spec.rb'
  test.verbose = true
end

namespace :build do
  YARD::Rake::YardocTask.new :doc
end

task :rubocop do
  sh "rubocop"
end
