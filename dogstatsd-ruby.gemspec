$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require "datadog/statsd"

Gem::Specification.new do |s|
  s.name = "dogstatsd-ruby"
  s.version = Datadog::Statsd::VERSION

  s.authors = ["Rein Henrichs"]

  s.summary = "A Ruby DogStatsd client"
  s.description = "A Ruby DogStastd client"
  s.email = "code@datadoghq.com"

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/DataDog/dogstatsd-ruby/issues",
    "changelog_uri"     => "https://github.com/DataDog/dogstatsd-ruby/blob/v#{s.version}/CHANGELOG.md",
    "documentation_uri" => "https://www.rubydoc.info/gems/dogstatsd-ruby/#{s.version}",
    "source_code_uri"   => "https://github.com/DataDog/dogstatsd-ruby/tree/v#{s.version}"
  }

  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.md"
  ]
  s.files = Dir["LICENSE.txt", "README.md", "lib/**/*.rb",]
  s.homepage = "https://github.com/DataDog/dogstatsd-ruby"
  s.licenses = ["MIT"]
  s.required_ruby_version = '>= 2.0.0'
end

