require 'sidekiq'
require '../../lib/datadog/statsd'

# How to test these examples:
#  - Run a redis server on port 6379:
#      $ docker run --rm --name redis -d -p6379:6379 redis
#  - Start sidekiq with this file:
#      $ sidekiq -d -r ./sidekiq_example.rb
#  - In another shell, perform the jobs using:
#      $ echo "ExampleWorkerInstance.perform_async"| irb -r ./sidekiq_example.rb
#      or
#      $ echo "ExampleEphemeralInstance.perform_async"| irb -r ./sidekiq_example.rb

# This Sidekiq worker uses a DogStatsD instance created every time this worker job
# is executed. Because of that, it is important to close this created client to
# free the resources it is using (a socket and a thread).
# Closing the client will also invoke "flush(sync: true)" to ensure metrics are
# flushed even if the client instance internal buffer is not full.
class ExampleEphemeralInstance
  include Sidekiq::Worker
  def perform()
    client = Datadog::Statsd.new('localhost', 8125)
    client.increment('example_metric.sample', tags: ['environment:dev'])
    # flush all metrics created during the job execution and free resources used by
    # this ephemeral dogstatsd client instance:
    client.close()
    puts("Metrics flushed and client closed")
  end
end

# This Sidekiq worker is using a single global instance created for the worker.
# It is instantiated when the worker is instantiated. It is important to flush the
# metrics at the end of the job execution in order to push them to the Datadog intake.
class ExampleWorkerInstance
  include Sidekiq::Worker
  STATSD_CLIENT = Datadog::Statsd.new('localhost', 8125)
  def perform()
    STATSD_CLIENT.increment('example_metric.sample', tags: ['environment:dev'])
    STATSD_CLIENT.flush(sync: true) # flush all metrics created during the job execution
    puts("Metrics flushed")
  end
end
