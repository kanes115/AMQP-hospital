defmodule Doctor do

  def start() do
    IO.puts "Starting doctor..."
    {:ok, connection} = AMQP.Connection.open
    {:ok, channel} = AMQP.Channel.open(connection)
    Common.declare_architecture(channel)
    {:ok, %{queue: callback_queue}} = AMQP.Queue.declare(channel,
                                                     "",
                                                     exclusive: false) #change to true later
    AMQP.Queue.bind(channel, callback_queue, 
                    Common.response_exchange(), routing_key: callback_queue)
    AMQP.Queue.bind(channel, callback_queue, 
                    Common.info_exchange())
    AMQP.Basic.consume(channel, callback_queue, nil, no_ack: true)
    spawn_input_manager()
    wait_for_input_or_answer(channel, callback_queue)
  end

  defp send_test_req(channel, patient, test_type, callback_queue, req_id) do
    IO.puts "Sending req with id #{req_id}"
    AMQP.Basic.publish(channel, Common.test_order_exchange(), test_type, patient,
                       reply_to: callback_queue, correlation_id: req_id)
  end

  defp wait_for_input_or_answer(channel, callback_queue) do
    receive do
      {:input, {test_type, surname}} ->
        req_id = Common.new_correlation()
        send_test_req(channel, surname, test_type, callback_queue, req_id)
        wait_for_input_or_answer(channel, callback_queue)
      {:basic_deliver, result, meta} ->
        case String.starts_with?(result, "[log]") do
          true ->
            IO.puts result
          _ ->
            IO.puts "I've got result for req_id #{meta.correlation_id}: #{result}"
        end
        wait_for_input_or_answer(channel, callback_queue)
    end
  end

  defp spawn_input_manager() do
    self_pid = self()
    spawn(fn() -> input_function(self_pid) end)
  end

  defp input_function(main_prog_pid) do
    input = IO.gets ">>"
    {test_type, surname} = case String.split(input, ":") do
                            [test_type, surname] ->
                              assert_proffesion(test_type, main_prog_pid)
                              {test_type, surname}
                            _ ->
                              input_function(main_prog_pid)
                          end
    case Common.proffession?(String.to_atom(test_type)) do
      true ->
        send main_prog_pid, {:input, {test_type, surname}} 
      _ ->
        IO.puts "Wrong test type"
    end
    input_function(main_prog_pid)
  end

  defp assert_proffesion(prof, main_prog_pid) do
    case Common.proffession?(String.to_atom(prof)) do
      true ->
        :ok
      _ ->
        input_function(main_prog_pid)
    end
  end
  
end

Doctor.start
