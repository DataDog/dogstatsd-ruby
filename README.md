
dogstatsd-ruby
==============

A client for DogStatsd, an extension of the Statsd metric server for Datadog.

[![Build Status](https://secure.travis-ci.org/DataDog/dogstatsd-ruby.png)](http://travis-ci.org/DataDog/dogstatsd-ruby)

Quick Start Guide
-----------------

First install `dogstatsd-ruby`:

    gem install dogstatsd-ruby

Then start instrumenting your code:

    # Load the dogstats module.
    require 'statsd'

    # Create a stats instance.
    statsd = Statsd.new('localhost', 8125)

    # Increment a counter.
    statsd.increment('page.views')

    # Record a gauge.
    statsd.gauge('users.online', 123)

    # Sample a histogram
    statsd.histogram('file.upload.size', 1234)

    # Time a block of code
    statsd.time('page.render') do
      render_page('home.html')
    end

    # Tag a metric.
    statsd.histogram('query.time', 10, :tags => ["version:1"])

Documentation
-------------

Full API documentation is available
[here](http://www.rubydoc.info/github/DataDog/dogstatsd-ruby/master/frames).


Feedback
--------

To suggest a feature, report a bug, or general discussion, head over
[here](http://github.com/DataDog/dogstatsd-ruby/issues/).


Credits
-------

dogstatsd-ruby is forked from Rien Henrichs [original Statsd
client](https://github.com/reinh/statsd).

Copyright (c) 2011 Rein Henrichs. See LICENSE.txt for
further details.
