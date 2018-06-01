$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require "datadog/statsd"

Gem::Specification.new do |s|
  s.name = "dogstatsd-ruby"
  s.version = Datadog::Statsd::VERSION

  s.authors = ["Rein Henrichs"]

  s.summary = "A Ruby DogStatsd client"
  s.description = "A Ruby DogStastd client"
  s.email = "code@datadoghq.com"

  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.md"
  ]
  s.files = Dir["LICENSE.txt", "README.md", "lib/**/*.rb",]
  s.homepage = "http://github.com/datadog/dogstatsd-ruby"
  s.licenses = ["MIT"]
end

