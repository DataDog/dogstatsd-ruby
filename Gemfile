source 'https://rubygems.org'

gem 'rake', '10.1.0'
gem 'rack', '~> 1.6'
gem 'minitest'
gem "yard", "~> 0.8.7.3"
gem 'single_cov'
gem 'concurrent-ruby', '~> 1.0.5'

if RUBY_VERSION >= "2.0.0"
  gem 'rubocop', "~> 0.49.0" # bump this and TargetRubyVersion once we drop ruby 1.9
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
  if RUBY_VERSION.start_with?("1.9")
    gem 'json', '< 2'
    gem 'public_suffix', '< 1.5'
    gem 'rdoc', '< 5'
    gem 'term-ansicolor', '< 1.4'
    gem 'webmock', '< 2.3'
    gem 'nokogiri', '< 1.7'
  else
    gem 'json'
  end
end
