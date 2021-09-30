source 'https://rubygems.org'

gemspec

if RUBY_VERSION < '2.1.0'
  gem 'rake', '12.3.2'
  gem 'minitest', '5.12.0'
  gem 'parallel', '1.13.0'
  gem 'single_cov', '1.5.0'
else
  gem 'rake', '>= 12.3.3'
  gem 'minitest'
  gem 'parallel'
  gem 'single_cov'
end

gem 'minitest-matchers'
gem 'yard', '~> 0.9.20'
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
  gem 'rspec'
  gem 'rspec-its'
  gem 'timecop'

  if RUBY_VERSION < '2.1.0'
    gem 'byebug', '9.0.6'
    gem 'memory_profiler', '0.9.0'
    gem 'i18n', '~> 0.5'
    gem 'faker', '1.7.3'
  else
    gem 'byebug'
    gem 'faker'
  end

  gem 'pry'
end

group :test do
  gem 'mocha'
end
