# Threading model

On versions greater than 5.0, we changed the threading model of the library so that one instance of `Datadog::Statsd` could be shared between threads and so that the writes in the socket are non blocking.

When you instanciate a `Datadog::Statsd`, a companion thread is spawn. This thread will be called the Sender thread, as it is modeled by the [Sender](../lib/datadog/statsd/sender.rb) class.

This thread is automatically stopped when you close the statsd client (`Datadog::Statsd#close`). The communication between the current thread is managed through a standard Ruby Queue.

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

## Usual workflow

You push metrics to the statsd client which writes them quickly to the sender message queue. The sender thread receives those message, bufferize them and flush them to the connection when close the buffer limits.

## Flushing

When calling a flush, a specific control message (the `:flush` symbol) is sent to the sender thread. When finding it, it flushes its internal buffer into the connection.

## Rendez-vous

It is possible to ensure a message has been consumed by the sender thread and written to the buffer by simply calling a rendez-vous right after. This is done when you are doing a synchronized flush (calling `Datadog::Statsd#flush` with the `sync: true` option). 

This means the current thread is going to sleep and wait for a Queue which is given to the sender thread. When the sender thread reads this queue from its own message queue, it puts a placeholder message in it so that it wakes up the calling thread.

This is useful when closing the application or when checking unit tests.


