source 'https://rubygems.org'

gemspec

gem 'rake', '>= 12.3.3'
gem 'minitest'
gem 'minitest-matchers'
gem 'yard', '~> 0.9.20'
gem 'single_cov'
gem 'climate_control', '~> 0.2.0' 

if RUBY_VERSION >= '2.0.0'
  gem 'rubocop', '~> 0.50.0' # bump this and TargetRubyVersion once we drop ruby 2.0
end

if RUBY_VERSION < '2.2.2'
  gem 'rack', '~> 1.6' # required on older ruby versions
end

if RUBY_VERSION >= '2.3.0'
  gem 'allocation_stats'
end

group :development do
  gem 'benchmark-ips'
  gem 'benchmark-memory'
  gem 'faker'
  gem 'rspec'
  gem 'rspec-its'
  gem 'timecop'
  gem 'byebug'
  gem 'pry'
end

group :test do
  gem 'mocha'
end
