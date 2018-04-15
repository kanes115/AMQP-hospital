defmodule Admin do
  
  def start() do
    IO.puts "Starting admin..."
    {:ok, connection} = AMQP.Connection.open
    {:ok, channel} = AMQP.Channel.open(connection)
    Common.declare_architecture(channel)
    AMQP.Queue.declare(channel, "admin_q")
    AMQP.Queue.bind(channel, "admin_q", Common.test_order_exchange(),
                                                                   routing_key: "#")
    AMQP.Queue.bind(channel, "admin_q", Common.response_exchange(),
                                                                   routing_key: "#")
    AMQP.Basic.consume(channel, "admin_q", nil, no_ack: true)
    wait_for_message(channel)
  end

  defp wait_for_message(channel) do
    receive do
      {:basic_deliver, message, meta} ->
        log =  "[log] message: #{String.strip(message)} routing key: #{meta.routing_key}"
        IO.puts log
        AMQP.Basic.publish(channel,Common.info_exchange(), "", log)
        wait_for_message(channel)
    end
  end
end

Admin.start()
