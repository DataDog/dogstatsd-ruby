source 'https://rubygems.org'
gemspec

gem 'rake', '10.1.0'
gem 'rack', '~> 1.6'

group :development do
  gem "faker", "~> 1.2.0"
end

group :localdev do
  gem "yard", "~> 0.8.7.3"
  gem "redcarpet", "~> 3.1.1"
end

group :test do
  gem "timecop"
  gem 'tins', '~> 1.6.0'
  if RbConfig::CONFIG['ruby_version'].start_with?("1.9")
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
