# CHANGELOG

[//]: # (comment: Don't forget to update lib/datadog/statsd/version.rb:DogStatsd::Statsd::VERSION when releasing a new version)

## 5.6.2 / 2024.09.20

  * [OTHER] Ruby versions 3.2 and 3.3 are now supported. [#291][] by [@gdubicki][]
  * [IMPROVEMENT] Reduce memory allocations during tag and metric serialization. [#294][] by [@schlubbi][]
  * [IMPROVEMENT] Avoid allocations when using delay_serialization. [#295][] by [@jhawthorn][]

## 5.6.1 / 2023.09.07

  * [IMPROVEMENT] Add support for IPv6 UDP connection. [#280][] by [@kazwolfe][]

## 5.6.0 / 2023.07.10

  * [FEATURE] Add the `delay_serialization` option, allowing users to delay
    expensive serialization until a more convenient time, such as after an HTTP
    request has completed. In multi-threaded mode, it causes serialization to
    happen inside the sender thread. [#271][] by [@pudiva][] and
    [@BlakeWilliams][]

  * [FEATURE] Also, support the `sender_queue_size` in `single_thread` mode, so
    that it can benefit from the new `delay_serialization` option. Messages are
    now queued (possibly unserialized) until `sender_queue_size` is reached or
    `#flush` is called. It may be set to `Float::INFINITY`, so that messages
    are indefinitely queued until an explicit `#flush`. [#271][] by [@pudiva][]
    and [@BlakeWilliams][]

  * [IMPROVEMENT] Add support of `DD_DOGSTATSD_URL` for configuration through
    environment variable. Valid formats are: `udp://some-host`,
    `udp://some-host:port` and `unix:///path/to/unix.sock`.
    `DD_DOGSTATSD_URL` has priority on other environment vars (`DD_AGENT_HOST`,
    `DD_DOGSTATSD_PORT` and `DD_DOGSTATSD_SOCKET`) but does not throw an error
    if others are set, values are overridden instead. [#278][] by [@remeh][]

  * [BUGFIX] Fix NoMethodError when Datadog::Statsd is initialized without
    telemetry. [#272][] by [@matthewshafer][]

## 5.5.0 / 2022.06.01

  * [FEATURE] Add `distribution_time` method to facilitate measuring timing of a yielded block. [#248][] by [@jordan-brough][]

  * [BUGFIX] Stop flush timer before closing the queue [#257][] by [@abicky][]

  * [IMPROVEMENT] Various warnings removed [#258][] by [@abicky][]

  * [OTHER] Remove unused `rack` dependency [#260][] by [@remeh][]

## 5.4.0 / 2022.03.01

  * [IMPROVEMENT] Add a `pre_sampled` option to metric methods [#235][] by [@matthewshafer][]

  * [OTHER] Ruby versions earlier than 2.1.0 are no longer supported.  Ruby-2.0 was EOL as of 2016-02-24.

  * [OTHER] Ruby versions 3.0 and 3.1 are now supported, including a fix for keyword arguments to `StatsD#open`. [#240][]

## 5.3.3 / 2022.02.02

  * [IMPROVEMENT] Add option "buffer_flush_interval" to flush buffered metrics [#231][] by [@abicky][]

  * [IMPROVEMENT] Add Sender.queue_size limits to limit number of buffered metrics [#232][] by [@djmitche][]

  * [IMPROVEMENT] The client can now be configured to use UDS via the `DD_DOGSTATSD_SOCKET` environment variable.
    This variable does not take precedence over any explicit parameters passed to the Statsd constructor.
    [#227][] by [@djmitche][]


## 5.3.2 / 2021.11.03

  * [OTHER] add a warning message for the v5.x update on install [#222][] by [@djmitche][]

## 5.3.1 / 2021.10.21

  * [OTHER] restore connection opening behavior from before 5.3.0 (connections not opened on client instantiation but on the first write instead) [#214][] by [@remeh][]

## 5.3.0 / 2021.10.06

  * [ENHANCEMENT] Automatically re-allocate resources (e.g. background thread) if `dogstatsd-ruby` is used in an application using forks [#205][] by [@remeh][]

    This will help in scenarios where applications are not handling cleanup/re-creation of the dogstatsd-ruby instances in forked processes.
    If you are an user of v4.x versions of `dogstatsd-ruby` and want to migrate to v5.x, please make sure to go through [this section of the README](https://github.com/DataDog/dogstatsd-ruby#v5x-common-pitfalls) and through the [migration guide](https://github.com/DataDog/dogstatsd-ruby#migrating-from-v4x-to-v5x).
  * [BUGFIX] Fix client telemetry in applications using forks [#205][] by [@remeh][]

Please note that this version will emit a deprecation message if you are using `ruby < 2.1`: we plan to drop support for ruby 2.0 in a future minor release.

## 5.2.0 / 2021.07.01

  * [FEATURE] Add `single_thread` mode for users having issues with the companion thread. [#194][] by [@remeh][]

You can use this mode to avoid spawning a companion thread while using v5.x versions:

```ruby
# Import the library
require 'datadog/statsd'

# Create a DogStatsD client instance.
statsd = Datadog::Statsd.new('localhost', 8125, single_thread: true)
...
# release resources used by the client instance and flush last metrics
statsd.close()
```

Note that if you want to restore the behavior of v4.x versions, you can also configure the buffer to flush on every metric submission:

```ruby
# Import the library
require 'datadog/statsd'

# Create a DogStatsD client instance using UDP
statsd = Datadog::Statsd.new('localhost', 8125, single_thread: true, buffer_max_pool_size: 1)
```

## 5.1.0 / 2021.06.17

  * [FEATURE] Flush last metrics on `Statsd#close` [#180][] by [@kbogtob][]
  * [ENHANCEMENT] Do not try to flush where there is no available `message_queue` [#189][] by [@remeh][]
  * [OTHER] Add pry to development dependencies and enable gem in Gemfile [#192][] by [@ivoanjo][]
  * [OTHER] Expand Ruby Support to Rubies 2.6, 2.7, and 3.0 [#191][] by [@laserlemon][]

### Known issues

  * If the DogStatsD client is instantiated before a `fork`, the forked process won't copy the companion thread that the original client needs to flush and the client won't work properly. This issue will be addressed in an upcoming version. If you are concerned by this issue, please read [this section of the README](https://github.com/DataDog/dogstatsd-ruby#v5x-common-pitfalls).

## 5.0.1 / 2021.04.09

  * [OTHER] Re-introduce a `Statsd#batch` method to help with compatibility with v4.x versions:
      - It is deprecated and will be removed in v6.x
      - It does not have the exact same behavior as the batch method from v4.x versions
      since the flush could now automatically occur while the batch block is executed if
      the buffer has been filled. [#176][] by [@remeh][]
  * [BUGFIX] Safely close concurrent resources on Sender [#175][] by [@marcotc][]

## 5.0.0 / 2021.04.07

**API breaking changes**

1. This new major version uses automatic buffering with preemptive flushing, there is no need to manually batch the metrics together anymore.
The preemptive flushing part means that just before the buffer gets full, a flush is triggered.
However, manual flush is still possible with the `Statsd#flush` method and is necessary to synchronously
send your metrics. The `Statsd#batch` method has been deprecated from the API.

2. Every instance of the client will spawn a companion thread for the new flush mechanism: it is important to close every instance using the method `Statsd#close`.

3. As of (1), the metrics are now buffered before being sent on the network, you have to use the `Statsd#flush`
method to force their sending through the socket. Note that the companion thread will automatically flush the buffered metrics if the buffer gets full or when you are closing the instance.

4. `Statsd#initialize` parameter `max_buffer_bytes` has been renamed to `buffer_max_payload_size` for consistency with the new automatic batch strategy. Please note the addition of `buffer_max_pool_size` to limit the maximum amount of *messages* to buffer. `disable_telemetry` has been renamed `telemetry_enable`, please note the semantic inversion.

What would have been written this way with the v4 API:

```ruby
require 'datadog/statsd'

statsd = Datadog::Statsd.new('127.0.0.1', 8125)

statsd.batch do |s|
  s.increment('example_metric.increment', tags: ['environment:dev'])
  s.gauge('example_metric.gauge', 123, tags: ['environment:dev'])
end

...

statsd.close()
```
should be written this way with the v5 API:
```ruby
require 'datadog/statsd'

statsd = Datadog::Statsd.new('127.0.0.1', 8125)

statsd.increment('example_metric.increment', tags: ['environment:dev'])
statsd.gauge('example_metric.gauge', 123, tags: ['environment:dev'])

# synchronous flush
statsd.flush(sync: true)

...

statsd.close()
```

5. `statsd.connection` should not be used anymore to get the `host`, the `port` and the `socket_path` of the statsd connection, they are now available directly in the `statsd` object.

### Commits

 * [IMPROVEMENT] Use asynchronous IO to avoid doing IO in the hot paths of the library users [#151][] by [@kbogtob][]
 * [IMPROVEMENT] Automatic buffering/preemptive flushing for better performances [#146][] by [@kbogtob][]

## 4.9.0 / 2021.03.23

A version 4.9.0 containing changes intended for 5.0.0 (with API breaking changes) has been released and was available on 2021-03-23.
It has been removed on 2021-03-24 and is not available anymore: v4.8.x should be used for latest v4 version of the gem, and v5.x.x versions should be used to benefit from the latest performances improvements.

## 4.8.3 / 2021.02.22

* [FEATURE] Add `truncate_if_too_long` option to the `event` call to truncate the event if it is too long instead of raising an error [#161][] by [@kazu9su][]

## 4.8.2 / 2020.10.16

* [IMPROVEMENT] The overhead of submitting metrics through `dogstatsd-ruby` has been reduced [#155][] [#156][] by [@marcotc][]

## 4.8.1 / 2020.05.25

* [BUGFIX] Send global tags even if no tags provided when using service check / event call [#147][] by [@f3ndot][]

## 4.8.0 / 2020.04.20

* [FEATURE] Add support of more environment variables for tagging [#140][] by [@delner][]
* [OTHER] Small optimizations [#139][] by [@tenderlove][]
* [BUGFIX] Properly close UDPSocket before creating a new one [#143][] by [@zachmccormick][]
* [OTHER] Refactor to make code more idiomatic [#138][] by [@kbogtob][]
* [OTHER] Refactor to translate unit tests to rspec [#135][] by [@kbogtob][]
* [OTHER] Bump rake requirement to >= 12.3.3 [#137][] by [@remeh][]

## 4.7.0 / 2020.02.14

* [FEATURE] Add configurable flush interval for the telemetry [#132][] by [@hush-hush][]
* [OTHER] Code structure and tests improvements [#131][] by [@kbogtob][]

## 4.6.0 / 2020.01.20

* [FEATURE] Adding telemetry to the dogstatsd client [#128][] by [@hush-hush][]

## 4.5.0 / 2019.08.22

* [BUGFIX] Handle ECONNREFUSED and typo fix [#113][] by [@redhotpenguin][]

## 4.4.0 / 2019.07.15

* [BUGFIX] Allow Integer date_happened and timestamp options [#115][]
* [OTHER] Update yard gem to 0.9.20 [#114][]

## 4.3.0 / 2019.06.24

* [FEATURE] Allow passing tags as a hash [#107][] by [@jtzemp][]
* [FEATURE] Added a setting for the global sample rate [#110][] by [@claytono][]
* [BUGFIX] Fix non-ascii event texts being truncated [#112][] by [@devleoper][]
* [BUGFIX] Display error if `write` fails due to a bad socket [#97][] by [@abicky][]

## 4.2.0 / 2019.04.04

* [FEATURE] Added environment vars support for host, port and entity id [#109][] by [@ahmed-mez][]

## 4.1.0 / 2019.03.08

* [FEATURE] Handle ENOTCONN [#102][] by [@blaines][]
* [IMPROVEMENT] Retry first before losing message when receiving ENOTCONN [#104][] by [@blaines][]

## 4.0.0 / 2018.08.20

* [IMPROVEMENT] Add `.open` for short-lived reporting that does not leave sockets around [#96][] by [@grosser][]
* [IMPROVEMENT] Extract batch logic into a class [#95][] by [@grosser][]
* [IMPROVEMENT] Extract connection for separation of concerns [#94][] by [@grosser][]
* [IMPROVEMENT] Fail fast on unknown options [#93][] by [@grosser][]
* [IMPROVEMENT] Always lazy connect [#92][] by [@grosser][]
* [IMPROVEMENT] Batch events and service checks too [#88][] by [@grosser][]
* [IMPROVEMENT] Remove bad argument after options [#83][] by [@grosser][]
* [IMPROVEMENT] Reduce object allocation and make all strings frozen on ruby 2.3+ [#78][] by [@grosser][]

### Breaking changes

* Remove deprecated `version` method [#91][] by [@grosser][]
* port / host / tags / namespace can no longer be set on the instance to allow thread-safety [#87][] by [@grosser][]
* port / host / socket_path readers are now on statsd.connection
* Make `logger` an instance var [#90][] by [@grosser][]
* Make `format_service_check` private [#89][] by [@grosser][]
* Improve code coverage / make `format_event` private [#84][] by [@grosser][]
* Set buffer size in bytes [#86][] by [@grosser][]
* max_buffer_size initializer argument removed and replaced with max_buffer_bytes (defaults to 8192)
* max_buffer_size/max_buffer_size= methods removed

## 3.3.0 / 2018.02.04

* [FEATURE] Add distribution support (beta). See [#72][].
* [IMPROVEMENT] A ton of cleanups and refinements courtesy of [@grosser][]. See [#68][], [#69][], [#73][], [#74][], [#75][], [#76][], [#77][].
* [IMPROVEMENT] Unify tag handling in `format_service_check`. See [#71][] by [@grosser][].
* [IMPROVEMENT] Use faster time method on ruby >= 2.1. See [#70][] by [@grosser][].

## 3.2.0 / 2017.12.21

* [IMPROVEMENT] Add statsd sample rate compat. [#67][], [@sj26][]

## 3.1.0 / 2017.11.23

* [FEATURE] Add Unix Domain Socket support. [#61][], [@sullerandras][]
* [IMPROVEMENT] Don't flush an empty buffer. [#58][], [@misterbyrne][]
* [BUGFIX] Use defaults when host/port are nil. [#56][], [@degemer][]
* [BUGFIX] Ignore nil tags and convert symbol. [#53][], [@pschambacher][]
* [FEATURE] Nest batch calls. [#52][], [@misterbyrne][]
* [BUGFIX] Convert tags to string type. [#51][], [@jacobbednarz][]

## 3.0.0 / 2017.05.18

* [FEATURE] Expose (socket) close method. [#46][], [@ramfjord][]
* [IMPROVEMENT] Retry once when send fails on a closed socket. [#46][], [@ramfjord][]
* [IMPROVEMENT] Use a instance variable to decide whether to batch or not. [#47][] [@fimmtiu][]

### Breaking changes

#### Host resolution

Host resolution was previously done every time a message was sent, it is now
done once when `Datadog::Statsd` is initiliazed (resulting in a non-negligible
performance improvement). [#44][], [@AMekss][]

`Datadog::Statsd.new(host, port)` will now raise a `SocketError` if unable to
resolve the `host`.

## 2.2.0 / 2017.01.12

* [IMPROVEMENT] Fewer string allocations, improves memory usage, [#40][], [@janester][]

## 2.1.0 / 2016.10.27

* [FEATURE] Add an optional `by` parameter for `#increment` and `#decrement`, [#33][]
* [BUGFIX] `#time`: record on all block exits, [#38][] [@nelhage][]
* [IMPROVEMENT] Replace string literals with symbols or frozen strings, [#37][] [@janester][]

## 2.0.0 / 2016.09.22

### Breaking changes

#### Namespace

The `Statsd` is now namespaced under the Datadog module. [#32][] [@djpate][]

To update:

* `require 'statsd'` -> `require 'datadog/statsd'`
* `Statsd` -> `Datadog::Statsd`

#### Tags

`,` is now stripped from tags to avoid unexpected behavior. [#34][] [@adimitrov][]

`Datadog::Statsd` also validates that it receives an array of tags, and strips `,` and `|` from them.

## 1.6.0 / 2015.12.21

* [IMPROVEMENT] Stop mutating input parameters, [#22][] [@olefriis][]

## 1.5.0 / 2015.05.20

### Notice

This release drops testing for Ruby 1.8.7.
Future versions are likely to introduce backward incompatibilities with < Ruby 1.9.3.

* [FEATURE] Add service checks support, [#11][]
* [FEATURE] Send time stat on failing block, [#16][] [@gleseur][]
* [BUGFIX] Add instance tags to `Statsd.event`, [#14][] [@gleseur][]
* [OTHER] Use `send_stat` instead of overriding Ruby `send` method, [#17][] [@sensadrome][]
* [OTHER] Changelog update

## 1.4.1 / 2014.09.29

* [BUGFIX] Fixed bug in message separator when batching metrics

## 1.4.0 / 2014.06.13

* [FEATURE] Added support for metrics batching

## 1.3.0 / 2014.03.27

* [FEATURE] Added support for submitting events

## 1.2.0 / 2013.07.10

* [FEATURE] Added global tags
* [FEATURE] Added ability to set namespace and tags from `Statsd#initialize`

## 1.1.0 / 2012.09.21

* [FEATURE] Added sets metrics

## 1.0.0 / 2012.06.14

* Initial release


<!--- The following link definition list is generated by PimpMyChangelog --->
[#11]: https://github.com/DataDog/dogstatsd-ruby/issues/11
[#14]: https://github.com/DataDog/dogstatsd-ruby/issues/14
[#16]: https://github.com/DataDog/dogstatsd-ruby/issues/16
[#17]: https://github.com/DataDog/dogstatsd-ruby/issues/17
[#22]: https://github.com/DataDog/dogstatsd-ruby/issues/22
[#32]: https://github.com/DataDog/dogstatsd-ruby/issues/32
[#33]: https://github.com/DataDog/dogstatsd-ruby/issues/33
[#34]: https://github.com/DataDog/dogstatsd-ruby/issues/34
[#37]: https://github.com/DataDog/dogstatsd-ruby/issues/37
[#38]: https://github.com/DataDog/dogstatsd-ruby/issues/38
[#40]: https://github.com/DataDog/dogstatsd-ruby/issues/40
[#44]: https://github.com/DataDog/dogstatsd-ruby/issues/44
[#46]: https://github.com/DataDog/dogstatsd-ruby/issues/46
[#47]: https://github.com/DataDog/dogstatsd-ruby/issues/47
[#51]: https://github.com/DataDog/dogstatsd-ruby/issues/51
[#52]: https://github.com/DataDog/dogstatsd-ruby/issues/52
[#53]: https://github.com/DataDog/dogstatsd-ruby/issues/53
[#56]: https://github.com/DataDog/dogstatsd-ruby/issues/56
[#58]: https://github.com/DataDog/dogstatsd-ruby/issues/58
[#61]: https://github.com/DataDog/dogstatsd-ruby/issues/61
[#67]: https://github.com/DataDog/dogstatsd-ruby/issues/67
[#68]: https://github.com/DataDog/dogstatsd-ruby/issues/68
[#69]: https://github.com/DataDog/dogstatsd-ruby/issues/69
[#70]: https://github.com/DataDog/dogstatsd-ruby/issues/70
[#71]: https://github.com/DataDog/dogstatsd-ruby/issues/71
[#72]: https://github.com/DataDog/dogstatsd-ruby/issues/72
[#73]: https://github.com/DataDog/dogstatsd-ruby/issues/73
[#74]: https://github.com/DataDog/dogstatsd-ruby/issues/74
[#75]: https://github.com/DataDog/dogstatsd-ruby/issues/75
[#76]: https://github.com/DataDog/dogstatsd-ruby/issues/76
[#77]: https://github.com/DataDog/dogstatsd-ruby/issues/77
[#78]: https://github.com/DataDog/dogstatsd-ruby/issues/78
[#83]: https://github.com/DataDog/dogstatsd-ruby/issues/83
[#84]: https://github.com/DataDog/dogstatsd-ruby/issues/84
[#86]: https://github.com/DataDog/dogstatsd-ruby/issues/86
[#87]: https://github.com/DataDog/dogstatsd-ruby/issues/87
[#88]: https://github.com/DataDog/dogstatsd-ruby/issues/88
[#89]: https://github.com/DataDog/dogstatsd-ruby/issues/89
[#90]: https://github.com/DataDog/dogstatsd-ruby/issues/90
[#91]: https://github.com/DataDog/dogstatsd-ruby/issues/91
[#92]: https://github.com/DataDog/dogstatsd-ruby/issues/92
[#93]: https://github.com/DataDog/dogstatsd-ruby/issues/93
[#94]: https://github.com/DataDog/dogstatsd-ruby/issues/94
[#95]: https://github.com/DataDog/dogstatsd-ruby/issues/95
[#96]: https://github.com/DataDog/dogstatsd-ruby/issues/96
[#97]: https://github.com/DataDog/dogstatsd-ruby/issues/97
[#102]: https://github.com/DataDog/dogstatsd-ruby/issues/102
[#104]: https://github.com/DataDog/dogstatsd-ruby/issues/104
[#107]: https://github.com/DataDog/dogstatsd-ruby/issues/107
[#109]: https://github.com/DataDog/dogstatsd-ruby/issues/109
[#110]: https://github.com/DataDog/dogstatsd-ruby/issues/110
[#112]: https://github.com/DataDog/dogstatsd-ruby/issues/112
[#113]: https://github.com/DataDog/dogstatsd-ruby/issues/113
[#114]: https://github.com/DataDog/dogstatsd-ruby/issues/114
[#115]: https://github.com/DataDog/dogstatsd-ruby/issues/115
[#128]: https://github.com/DataDog/dogstatsd-ruby/issues/128
[#131]: https://github.com/DataDog/dogstatsd-ruby/issues/131
[#132]: https://github.com/DataDog/dogstatsd-ruby/issues/132
[#135]: https://github.com/DataDog/dogstatsd-ruby/issues/135
[#137]: https://github.com/DataDog/dogstatsd-ruby/issues/137
[#138]: https://github.com/DataDog/dogstatsd-ruby/issues/138
[#140]: https://github.com/DataDog/dogstatsd-ruby/issues/140
[#143]: https://github.com/DataDog/dogstatsd-ruby/issues/143
[#146]: https://github.com/DataDog/dogstatsd-ruby/issues/146
[#147]: https://github.com/DataDog/dogstatsd-ruby/issues/147
[#151]: https://github.com/DataDog/dogstatsd-ruby/issues/151
[#155]: https://github.com/DataDog/dogstatsd-ruby/issues/155
[#156]: https://github.com/DataDog/dogstatsd-ruby/issues/156
[#161]: https://github.com/DataDog/dogstatsd-ruby/issues/161
[#175]: https://github.com/DataDog/dogstatsd-ruby/issues/175
[#176]: https://github.com/DataDog/dogstatsd-ruby/issues/176
[#180]: https://github.com/DataDog/dogstatsd-ruby/issues/180
[#181]: https://github.com/DataDog/dogstatsd-ruby/issues/181
[#192]: https://github.com/DataDog/dogstatsd-ruby/issues/192
[#194]: https://github.com/DataDog/dogstatsd-ruby/issues/194
[#205]: https://github.com/DataDog/dogstatsd-ruby/issues/205
[#214]: https://github.com/DataDog/dogstatsd-ruby/issues/214
[#222]: https://github.com/DataDog/dogstatsd-ruby/issues/222
[#231]: https://github.com/DataDog/dogstatsd-ruby/issues/231
[#232]: https://github.com/DataDog/dogstatsd-ruby/issues/232
[#235]: https://github.com/DataDog/dogstatsd-ruby/issues/235
[#240]: https://github.com/DataDog/dogstatsd-ruby/issues/240
[#248]: https://github.com/DataDog/dogstatsd-ruby/issues/248
[#257]: https://github.com/DataDog/dogstatsd-ruby/issues/257
[#258]: https://github.com/DataDog/dogstatsd-ruby/issues/258
[#260]: https://github.com/DataDog/dogstatsd-ruby/issues/260
[#271]: https://github.com/DataDog/dogstatsd-ruby/issues/271
[#272]: https://github.com/DataDog/dogstatsd-ruby/issues/272
[#278]: https://github.com/DataDog/dogstatsd-ruby/issues/278
[#280]: https://github.com/DataDog/dogstatsd-ruby/issues/280
[#291]: https://github.com/DataDog/dogstatsd-ruby/issues/291
[#294]: https://github.com/DataDog/dogstatsd-ruby/issues/294
[#295]: https://github.com/DataDog/dogstatsd-ruby/issues/295
[@AMekss]: https://github.com/AMekss
[@abicky]: https://github.com/abicky
[@adimitrov]: https://github.com/adimitrov
[@ahmed-mez]: https://github.com/ahmed-mez
[@blaines]: https://github.com/blaines
[@claytono]: https://github.com/claytono
[@degemer]: https://github.com/degemer
[@devleoper]: https://github.com/devleoper
[@djmitche]: https://github.com/djmitche
[@djpate]: https://github.com/djpate
[@f3ndot]: https://github.com/f3ndot
[@fimmtiu]: https://github.com/fimmtiu
[@gdubicki]: https://github.com/gdubicki
[@gleseur]: https://github.com/gleseur
[@grosser]: https://github.com/grosser
[@hush-hush]: https://github.com/hush-hush
[@ivoanjo]: https://github.com/ivoanjo
[@jacobbednarz]: https://github.com/jacobbednarz
[@janester]: https://github.com/janester
[@jhawthorn]: https://github.com/jhawthorn
[@jordan-brough]: https://github.com/jordan-brough
[@jtzemp]: https://github.com/jtzemp
[@kazu9su]: https://github.com/kazu9su
[@kazwolfe]: https://github.com/kazwolfe
[@kbogtob]: https://github.com/kbogtob
[@laserlemon]: https://github.com/laserlemon
[@marcotc]: https://github.com/marcotc
[@matthewshafer]: https://github.com/matthewshafer
[@misterbyrne]: https://github.com/misterbyrne
[@nelhage]: https://github.com/nelhage
[@olefriis]: https://github.com/olefriis
[@pschambacher]: https://github.com/pschambacher
[@ramfjord]: https://github.com/ramfjord
[@redhotpenguin]: https://github.com/redhotpenguin
[@remeh]: https://github.com/remeh
[@schlubbi]: https://github.com/schlubbi
[@sensadrome]: https://github.com/sensadrome
[@sj26]: https://github.com/sj26
[@sullerandras]: https://github.com/sullerandras
[@delner]: https://github.com/delner
[@tenderlove]: https://github.com/tenderlove
[@zachmccormick]: https://github.com/zachmccormick
[@pudiva]: https://github.com/pudiva
[@BlakeWilliams]: https://github.com/BlakeWilliams
