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
...
# release resources used by the client instance
statsd.close()
```
Or if you want to connect over Unix Domain Socket:
```ruby
# Connection over Unix Domain Socket
statsd = Datadog::Statsd.new(socket_path: '/path/to/socket/file')
...
# release resources used by the client instance
statsd.close()
```

Find a list of all the available options for your DogStatsD Client in the [DogStatsD-ruby rubydoc](https://www.rubydoc.info/github/DataDog/dogstatsd-ruby/master/Datadog/Statsd) or in the [Datadog public DogStatsD documentation](https://docs.datadoghq.com/developers/dogstatsd/?code-lang=ruby#client-instantiation-parameters).

### Migrating from v4.x to v5.x

If you are already using DogStatsD-ruby v4.x and you want to migrate to a version v5.x, the major
change concerning you is the new threading model (please see section Threading model):

In practice, it means two things:

1. Now that the client is buffering metrics before sending them, you have to manually
call the method `Datadog::Statsd#flush` if you want to force the sending of metrics. Note that the companion thread will automatically flush the buffered metrics if the buffer gets full or when you are closing the instance.

2. You have to make sure you are either:

  * using singletons instances of the DogStatsD client and not allocating one each time you need one, letting the buffering mechanism flush metrics, it's still a bad solution if the process later forks (see related section below). Or,
  * properly closing your DogStatsD client instance when it is not needed anymore using the method `Datadog::Statsd#close` to release the resources used by the instance and to close the socket

If you have issues with the companion thread or the buffering mode, you can instantiate a client that behaves exactly as in v4.x (i.e. no companion thread and flush on every metric submission):

```ruby
# Import the library
require 'datadog/statsd'

# Create a DogStatsD client instance using UDP
statsd = Datadog::Statsd.new('localhost', 8125, single_thread: true, buffer_max_pool_size: 1)
...
# to close the instance is not necessary in this case since metrics are flushed on submission
# but it is still a good practice and it explicitely closes the socket
statsd.close()
```

or

```ruby
# Import the library
require 'datadog/statsd'

# Create a DogStatsD client instance using UDS
statsd = Datadog::Statsd.new(socket_path: '/path/to/socket/file', single_thread: true, buffer_max_pool_size: 1)
...
# to close the instance is not necessary in this case since metrics are flushed on submission
# but it is still a good practice and it explicitely closes the socket
statsd.close()
```

### v5.x Common Pitfalls

Version v5.x of `dogstatsd-ruby` is using a companion thread for preemptive flushing, it brings better performances for application having a high-throughput of statsd metrics, but it comes with new pitfalls:

    * Applications forking after having created the dogstatsd instance: forking a process can't duplicate the existing threads, meaning that one of the processes won't have a companion thread to flush the metrics and will lead to missing metrics.
    * Applications creating a lot of different instances of the client without closing them: it is important to close the instance to free the thread and the socket it is using or it will lead to thread leaks.

If you are using [Sidekiq](https://github.com/mperham/sidekiq), please make sure to close the client instances that are instantiated. [See this example on using DogStatsD-ruby v5.x with Sidekiq](https://github.com/DataDog/dogstatsd-ruby/blob/master/examples/sidekiq_example.rb).

If you are using [Puma](https://github.com/puma/puma) or [Unicorn](https://yhbt.net/unicorn.git), please make sure to create the instance of DogStatsD in the workers, not in the main process before it forks to create its workers. See [this comment for more details](https://github.com/DataDog/dogstatsd-ruby/issues/179#issuecomment-845570345).

Applications that are in these situations but can't apply these recommendations should enable the `single_thread` mode which does not use a companion thread. Here is how to instantiate a client in this mode:

```ruby
# Import the library
require 'datadog/statsd'

# Create a DogStatsD client instance.
statsd = Datadog::Statsd.new('localhost', 8125, single_thread: true)
...
# release resources used by the client instance and flush last metrics
statsd.close()
```

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

After the client is created, you can start sending custom metrics to Datadog. See the dedicated [Metric Submission: DogStatsD documentation](https://docs.datadoghq.com/metrics/dogstatsd_metrics_submission/?tab=ruby) to see how to submit all supported metric types to Datadog with working code examples:

* [Submit a COUNT metric](https://docs.datadoghq.com/metrics/dogstatsd_metrics_submission/?code-lang=ruby#count).
* [Submit a GAUGE metric](https://docs.datadoghq.com/metrics/dogstatsd_metrics_submission/?code-lang=ruby#gauge).
* [Submit a SET metric](https://docs.datadoghq.com/metrics/dogstatsd_metrics_submission/?code-lang=ruby#set)
* [Submit a HISTOGRAM metric](https://docs.datadoghq.com/metrics/dogstatsd_metrics_submission/?code-lang=ruby#histogram)
* [Submit a DISTRIBUTION metric](https://docs.datadoghq.com/metrics/dogstatsd_metrics_submission/?code-lang=ruby#distribution)

Some options are suppported when submitting metrics, like [applying a Sample Rate to your metrics](https://docs.datadoghq.com/metrics/dogstatsd_metrics_submission/?tab=ruby#metric-submission-options) or [tagging your metrics with your custom tags](https://docs.datadoghq.com/metrics/dogstatsd_metrics_submission/?tab=ruby#metric-tagging). Find all the available functions to report metrics in the [DogStatsD-ruby rubydoc](https://www.rubydoc.info/github/DataDog/dogstatsd-ruby/master/Datadog/Statsd).

### Events

After the client is created, you can start sending events to your Datadog Event Stream. See the dedicated [Event Submission: DogStatsD documentation](https://docs.datadoghq.com/events/guides/dogstatsd/?code-lang=ruby) to see how to submit an event to Datadog your Event Stream.

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

## Threading model

On versions greater than 5.0, we changed the threading model of the library so that one instance of `Datadog::Statsd` could be shared between threads and so that the writes in the socket are non blocking.

When you instantiate a `Datadog::Statsd`, a companion thread is spawned. This thread will be called the Sender thread, as it is modeled by the [Sender](../lib/datadog/statsd/sender.rb) class. Please use `single_thread: true` while creating an instance if you don't want to or can't use a companion thread.

This thread is stopped when you close the statsd client (`Datadog::Statsd#close`). It also means that allocating a lot of statsd clients without closing them properly when not used anymore
could lead to a thread leak (even though they will be sleeping, blocked on IO).
The communication between the current thread is managed through a standard Ruby Queue.

The sender thread has the following logic (Code present in the method `Datadog::Statsd::Sender#send_loop`):

```
while the sender message queue is not closed do
  read message from sender message queue

  if message is a Control message to flush
    flush buffer in connection
  else if message is a Control message to synchronize
    synchronize with calling thread
  else
    add message to the buffer
  end
end while
```

Most of the time, the sender thread is blocked and sleeping when doing a blocking read from the sender message queue.

We can see that there is 3 different kind of messages:

* a control message to flush the buffer in the connection
* a control message to synchronize any thread with the sender thread
* a message to append to the buffer

There is also an implicit message which is closing the queue as it will stop blocking read from the message queue (if happening) and thus, stop the sender thread.

### Usual workflow

You push metrics to the statsd client which writes them quickly to the sender message queue. The sender thread receives those message, buffers them and flushes them to the connection when the buffer limit is reached.

### Flushing

When calling a flush, a specific control message (the `:flush` symbol) is sent to the sender thread. When finding it, it flushes its internal buffer into the connection.

### Rendez-vous

It is possible to ensure a message has been consumed by the sender thread and written to the buffer by simply calling a rendez-vous right after. This is done when you are doing a synchronized flush (calling `Datadog::Statsd#flush` with the `sync: true` option).

This means the current thread is going to sleep and wait for a Queue which is given to the sender thread. When the sender thread reads this queue from its own message queue, it puts a placeholder message in it so that it wakes up the calling thread.

This is useful when closing the application or when checking unit tests.

## Versioning

This Ruby gem is using [Semantic Versioning](https://guides.rubygems.org/patterns/#semantic-versioning) but please note that supported Ruby versions can change in a minor release of this library. As much as possible, we will add a "future deprecation" message in the minor release preceding the one dropping the support.

## Credits

dogstatsd-ruby is forked from Rein Henrichs [original Statsd
client](https://github.com/reinh/statsd).

Copyright (c) 2011 Rein Henrichs. See LICENSE.txt for
further details.
