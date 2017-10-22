defmodule Pastry do
  def setInitialNetwork(numNodes) do
    PastryInit.pastryInit(numNodes)
    Enum.each(:global.registered_names, fn(actor) ->
      send actor, :sendRequest
      #GenServer.cast(actor, :sendRequest)
    end)
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

    #{:ok, serverPid} = GenServer.start(__MODULE__, server, name: :server)
    #GenServer.call(serverPid, )
    setInitialNetwork(numNodes)

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
