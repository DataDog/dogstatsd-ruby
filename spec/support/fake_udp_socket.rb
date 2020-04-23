class FakeUDPSocket
  def initialize(copy_message: false)
    @buffer = []
    @error_on_send = nil
    @copy_message = copy_message
  end

  def send(message, *args)
    raise @error_on_send if @error_on_send
    message = message.dup if @copy_message

    @buffer.push [message]
  end

  def recv
    @buffer.shift
  end

  def to_s
    inspect
  end

  def inspect
    "<FakeUDPSocket: #{@buffer.inspect}>"
  end

  def error_on_send(err)
    @error_on_send = err
  end

  def connect(*args)
  end

  def close
  end
end