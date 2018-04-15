defmodule Common do

  def available_proffesions(), do: [:knee, :hip, :elbow]

  def proffession?(prof) do
    available_proffesions = [:knee, :hip, :elbow]
    Enum.member?(available_proffesions, prof)
  end

  def declare_architecture(channel) do
    AMQP.Exchange.declare(channel, test_order_exchange(), :topic)
    AMQP.Exchange.declare(channel, response_exchange(), :topic)
    AMQP.Exchange.declare(channel, info_exchange(), :fanout)
    Enum.each(available_proffesions(), fn(prof) -> declare_queue(channel, q_name_for(prof)) end)
    Enum.each(available_proffesions(), fn(prof) -> bind(channel, prof) end)
  end

  def error(reason) do
    IO.puts reason
    System.halt
  end

  defp declare_queue(channel, name) do
    AMQP.Queue.declare(channel, name)
  end

  defp bind(channel, prof) do
    AMQP.Queue.bind(channel, q_name_for(prof), test_order_exchange(), routing_key: key_for(prof))
  end

  def q_name_for(prof), do: Atom.to_string(prof) <> "_q"
  defp key_for(prof), do: Atom.to_string(prof)
  def test_order_exchange, do: "TEST_ORDER_EXCHANGE"
  def response_exchange, do: "RESPONSE_EXCHANGE"
  def info_exchange, do: "INFO_EXCHANGE"

  def new_correlation() do
    :erlang.unique_integer
    |> :erlang.integer_to_binary
    |> Base.encode64
  end
end

