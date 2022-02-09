require 'datadog/statsd'

require 'rspec'
require 'rspec/its'
require 'byebug'
require 'timeout'
require 'timecop'
require 'stringio'
require 'logger'
require 'faker'
require 'allocation_stats' if RUBY_VERSION >= '2.3.0'
require 'climate_control'

Dir[File.join(File.dirname(__FILE__), '/support/**/*.rb')].each { |f| require f }
Dir[File.join(File.dirname(__FILE__), '/matchers/**/*.rb')].each { |f| require f }
Dir[File.join(File.dirname(__FILE__), '/shared/**/*.rb')].each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.disable_monkey_patching!

  if config.files_to_run.one?
    config.default_formatter = "doc"
  end

  config.expose_dsl_globally = true

  config.warnings = true
end
