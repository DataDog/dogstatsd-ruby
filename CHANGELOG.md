# CHANGELOG

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
[#114]: https://github.com/DataDog/dogstatsd-ruby/issues/114
[#115]: https://github.com/DataDog/dogstatsd-ruby/issues/115
[@AMekss]: https://github.com/AMekss
[@abicky]: https://github.com/abicky
[@adimitrov]: https://github.com/adimitrov
[@ahmed-mez]: https://github.com/ahmed-mez
[@blaines]: https://github.com/blaines
[@claytono]: https://github.com/claytono
[@degemer]: https://github.com/degemer
[@devleoper]: https://github.com/devleoper
[@djpate]: https://github.com/djpate
[@fimmtiu]: https://github.com/fimmtiu
[@gleseur]: https://github.com/gleseur
[@grosser]: https://github.com/grosser
[@jacobbednarz]: https://github.com/jacobbednarz
[@janester]: https://github.com/janester
[@jtzemp]: https://github.com/jtzemp
[@misterbyrne]: https://github.com/misterbyrne
[@nelhage]: https://github.com/nelhage
[@olefriis]: https://github.com/olefriis
[@pschambacher]: https://github.com/pschambacher
[@ramfjord]: https://github.com/ramfjord
[@sensadrome]: https://github.com/sensadrome
[@sj26]: https://github.com/sj26
[@sullerandras]: https://github.com/sullerandras
