require 'bundler/setup'
require 'bundler/gem_tasks'
require 'rake/testtask'
require 'yard'

task default: [:spec, :rubocop]

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
  # rubocop:disable Lint/HandleExceptions
rescue LoadError
  # rubocop:enable Lint/HandleExceptions
end

namespace :build do
  YARD::Rake::YardocTask.new :doc
end

task :rubocop do
  sh 'rubocop'
end
