defmodule Pastry do
  use GenServer
  def handle_call({numNodes, numRequests}, _, numHops) do
    Pastry.callAPIs(numNodes, numRequests)
    {:reply, numHops, numHops}
  end

  def callAPIs(numNodes, numRequests) do
    PastryInit.pastryInit(numNodes)
    #IO.inspect :global.registered_names
    Enum.each(:global.registered_names, fn(actor) ->
      GenServer.call(actor, {:update, actor})
      IO.puts "updated"
      IO.inspect actor
    end)
    Enum.each(:global.registered_names, fn(actor) ->
      send actor, {actor, :sendRequest, numRequests}
    end)
    #receive do
    #  :ok ->
    #    true
    #end
  end

  def handle_cast(newNumHops, numHops) do
    {:noreply, numHops+newNumHops}
  end 
  def init(numHops) do
    {:ok, numHops}
  end

  def main(args) do
    numNodes = args
              |> parse_args
              |> Enum.at(0)
              |> Integer.parse(10)
              |> elem(0)

    numRequests = args
                  |> parse_args
                  |> Enum.at(1)
                  |> Integer.parse(10)
                  |> elem(0)


    {:ok, _} = GenServer.start(__MODULE__, 0, name: :masterProcess)
    GenServer.call(:masterProcess, {numNodes, numRequests}, :infinity)
    #IO.puts "total Hops #{totalHops}"

    receive do
      :over ->
        true
    end
  end

  #parsing the input argument
  defp parse_args(args) do
    {_, word, _} = args
    |> OptionParser.parse(strict: [:integer, :integer])
    word
  end
end
