require 'rubygems'
require 'yard'
require 'rake/testtask'
require 'bundler'

task :default => :spec

Rake::TestTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.pattern = 'spec/**/*_spec.rb'
  spec.verbose = true
end

YARD::Rake::YardocTask.new

Bundler::GemHelper.install_tasks
