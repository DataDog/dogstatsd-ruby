source 'https://rubygems.org'

gem 'rake', '>= 12.3.3'
gem 'rack', '~> 1.6'
gem 'minitest'
gem 'minitest-matchers'
gem "yard", "~> 0.9.20"
gem 'single_cov'

if RUBY_VERSION >= "2.0.0"
  gem 'rubocop', "~> 0.50.0" # bump this and TargetRubyVersion once we drop ruby 2.0
end

if RUBY_VERSION >= "2.3.0"
  gem 'allocation_stats'
end

group :development do
  gem "faker", "~> 1.2.0"
end

group :localdev do
  gem "redcarpet", "~> 3.1.1"
end

group :test do
  gem 'tins', '~> 1.6.0'
  gem 'mocha'
  gem 'json'
end
