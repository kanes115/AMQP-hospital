defmodule Technician do
  
  defp parse_args(args) do
    profs_atoms = case args do
      [_, _] = prof_list -> 
        prof_list
        |> Enum.map(fn(prof_string) -> String.to_atom(prof_string) end)
      _ -> 
        Common.error("Wrong argument nuber")
    end
    case Enum.all?(profs_atoms, &Common.proffession?/1) do
      true ->
        profs_atoms
      _ ->
        Common.error("Wrong proffesions")
    end
  end

  defp wait_for_messages(channel) do
    receive do
      {:basic_deliver, message, meta} ->
	response = String.trim(message) <> meta.routing_key <> "done"
        case meta.correlation_id do
          :undefined -> #it's log
            IO.puts message
          _ -> #it's request
	    IO.puts "Got req of id #{meta.correlation_id}"
            AMQP.Basic.publish(channel,
                               Common.response_exchange(),
                               meta.reply_to,
                               response,
                               correlation_id: meta.correlation_id)
        end
        wait_for_messages(channel)
    end
  end

  def start() do
    [p1, p2] = proffessions = parse_args(System.argv)
    IO.puts "Starting technician who knows: #{p1} and #{p2}"
    
    {:ok, connection} = AMQP.Connection.open
    {:ok, channel} = AMQP.Channel.open(connection)

    Common.declare_architecture(channel)
    {:ok, %{queue: info_q}} = AMQP.Queue.declare(channel,
                                                 "",
                                                 exclusive: false) #change to true later
    AMQP.Queue.bind(channel, info_q, Common.info_exchange())
    AMQP.Basic.consume(channel, info_q, nil, no_ack: true)
    proffessions
    |> Enum.each(fn(prof) -> 
		   AMQP.Basic.consume(channel, Common.q_name_for(prof), nil, no_ack: true) end)

    wait_for_messages(channel)
    
    AMQP.Connection.close(connection)
  end

end

Technician.start
