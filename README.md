# dogstatsd-ruby

A client for DogStatsD, an extension of the StatsD metric server for Datadog. Full API documentation is available in [DogStatsD-ruby rubydoc](https://www.rubydoc.info/github/DataDog/dogstatsd-ruby/master/Datadog/Statsd).

[![Build Status](https://secure.travis-ci.org/DataDog/dogstatsd-ruby.svg)](http://travis-ci.org/DataDog/dogstatsd-ruby)

See [CHANGELOG.md](CHANGELOG.md) for changes. To suggest a feature, report a bug, or general discussion, [open an issue](http://github.com/DataDog/dogstatsd-ruby/issues/).

## Installation

First install the library:

```
gem install dogstatsd-ruby
```

## Configuration

To instantiate a DogStatsd client:

```ruby
# Import the library
require 'datadog/statsd'

# Create a DogStatsD client instance.
statsd = Datadog::Statsd.new('localhost', 8125)
```
Or if you want to connect over Unix Domain Socket:
```ruby
# Connection over Unix Domain Socket
statsd = Datadog::Statsd.new(socket_path: '/path/to/socket/file')
```

Find a list of all the available options for your DogStatsD Client in the [DogStatsD-ruby rubydoc](https://www.rubydoc.info/github/DataDog/dogstatsd-ruby/master/Datadog/Statsd) or in the [Datadog public DogStatsD documentation](https://docs.datadoghq.com/developers/dogstatsd/?tab=ruby#client-instantiation-parameters).

### Origin detection over UDP

Origin detection is a method to detect which pod DogStatsD packets are coming from in order to add the pod's tags to the tag list.

To enable origin detection over UDP, add the following lines to your application manifest
```yaml
env:
  - name: DD_ENTITY_ID
    valueFrom:
      fieldRef:
        fieldPath: metadata.uid
```
The DogStatsD client attaches an internal tag, `entity_id`. The value of this tag is the content of the `DD_ENTITY_ID` environment variable, which is the pod’s UID.

## Usage

In order to use DogStatsD metrics, events, and Service Checks the Agent must be [running and available](https://docs.datadoghq.com/developers/dogstatsd/?tab=ruby).

### Metrics

After the client is created, you can start sending custom metrics to Datadog. See the dedicated [Metric Submission: DogStatsD documentation](https://docs.datadoghq.com/developers/metrics/dogstatsd_metrics_submission/?tab=ruby) to see how to submit all supported metric types to Datadog with working code examples:

* [Submit a COUNT metric](https://docs.datadoghq.com/developers/metrics/dogstatsd_metrics_submission/?tab=ruby#count).
* [Submit a GAUGE metric](https://docs.datadoghq.com/developers/metrics/dogstatsd_metrics_submission/?tab=ruby#gauge).
* [Submit a SET metric](https://docs.datadoghq.com/developers/metrics/dogstatsd_metrics_submission/?tab=ruby#set)
* [Submit a HISTOGRAM metric](https://docs.datadoghq.com/developers/metrics/dogstatsd_metrics_submission/?tab=ruby#histogram)
* [Submit a DISTRIBUTION metric](https://docs.datadoghq.com/developers/metrics/dogstatsd_metrics_submission/?tab=ruby#distribution)

Some options are suppported when submitting metrics, like [applying a Sample Rate to your metrics](https://docs.datadoghq.com/developers/metrics/dogstatsd_metrics_submission/?tab=ruby#metric-submission-options) or [tagging your metrics with your custom tags](https://docs.datadoghq.com/developers/metrics/dogstatsd_metrics_submission/?tab=ruby#metric-tagging). Find all the available functions to report metrics in the [DogStatsD-ruby rubydoc](https://www.rubydoc.info/github/DataDog/dogstatsd-ruby/master/Datadog/Statsd).

### Events

After the client is created, you can start sending events to your Datadog Event Stream. See the dedicated [Event Submission: DogStatsD documentation](https://docs.datadoghq.com/developers/events/dogstatsd/?tab=ruby) to see how to submit an event to Datadog your Event Stream.

### Service Checks

After the client is created, you can start sending Service Checks to Datadog. See the dedicated [Service Check Submission: DogStatsD documentation](https://docs.datadoghq.com/developers/service_checks/dogstatsd_service_checks_submission/?tab=ruby) to see how to submit a Service Check to Datadog.

### Maximum packets size in high-throughput scenarios

In order to have the most efficient use of this library in high-throughput scenarios,
default values for the maximum packets size have already been set for both UDS (8192 bytes)
and UDP (1432 bytes) in order to have the best usage of the underlying network.
However, if you perfectly know your network and you know that a different value for the maximum packets
size should be used, you can set it with the parameter `buffer_max_payload_size`. Example:

```ruby
# Create a DogStatsD client instance.
statsd = Datadog::Statsd.new('localhost', 8125, buffer_max_payload_size: 4096)
```

## Credits

dogstatsd-ruby is forked from Rien Henrichs [original Statsd
client](https://github.com/reinh/statsd).

Copyright (c) 2011 Rein Henrichs. See LICENSE.txt for
further details.
