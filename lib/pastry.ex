import States
import PastryInit

defmodule Pastry do
  def setInitialNetwork(numNodes) do
    PastryInit.pastryInit(numNodes)
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
