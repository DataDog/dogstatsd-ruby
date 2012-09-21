$:.unshift File.expand_path("../lib", __FILE__)
require "statsd"

Gem::Specification.new do |s|
  s.name = "dogstatsd-ruby"
  s.version = Statsd.VERSION

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

  s.add_development_dependency(%q<minitest>, [">= 0"])
  s.add_development_dependency(%q<yard>, ["~> 0.6.0"])
  s.add_development_dependency(%q<jeweler>, ["~> 1.8"])
  s.add_development_dependency(%q<simplecov>, [">= 0"])
end

