defmodule Pastry do
  use GenServer
  def handle_call({numNodes, numRequests}, _, {totalRequests, numHops, boss}) do
    Pastry.callAPIs(numNodes, numRequests)
    {:reply, numHops, {totalRequests, numHops, boss}}
  end

  #wrapper function to create network and run requests
  def callAPIs(numNodes, numRequests) do
    PastryInit.pastryInit(numNodes)
    Enum.each(:global.registered_names, fn(actor) ->
      GenServer.call(actor, {:update, actor})
    end)
    Enum.each(:global.registered_names, fn(actor) ->
      send actor, {actor, :sendRequest, numRequests}
    end)
  end

  def handle_info(newNumHops, {1, numHops, boss}) do
    send boss, newNumHops+numHops
    {:noreply, {0, numHops+newNumHops, boss}}
  end
  def handle_info(newNumHops, {requestsLeft, numHops, boss}) do
   {:noreply, {requestsLeft-1, numHops+newNumHops, boss}}
  end 

  def init(state) do
    {:ok, state}
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

    totalRequests = numNodes * numRequests
    {:ok, _} = GenServer.start(__MODULE__, {totalRequests, 0, self()}, name: :masterProcess)
    GenServer.call(:masterProcess, {numNodes, numRequests}, :infinity)

    receive do
      numHops->
        IO.puts "Average number of hops: #{numHops/totalRequests}"
    end
  end

  #parsing the input argument
  defp parse_args(args) do
    {_, word, _} = args
    |> OptionParser.parse(strict: [:integer, :integer])
    word
  end
end
