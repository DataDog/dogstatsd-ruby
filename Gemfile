source 'https://rubygems.org'
gemspec

gem 'rake', '10.1.0'
gem 'rack', '~> 1.6'
gem 'minitest'
gem "yard", "~> 0.8.7.3"
gem 'jeweler', '~> 1.8'
gem 'simplecov'

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
