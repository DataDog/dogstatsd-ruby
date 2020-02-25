class FakeUDPSocket
  def initialize
    @buffer = []
    @error_on_send = nil
  end

  def send(message, *)
    raise @error_on_send if @error_on_send
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
end