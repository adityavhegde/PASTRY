import States

defmodule Pastry do
@b 4
use GenServer
  #spawning actors
  def pastryInit(_, 0) do
    true
  end
  def pastryInit(numNodes) do
    newNode = Pastry.spawnProcess(numNodes)
    newNode |> pastryInit(numNodes-1)
  end
  def pastryInit(nearbyNode, numNodes) do
    newNode = Pastry.spawnProcess(numNodes)
    Pastry.sendJoin(newNode, nearbyNode)
    newNode |> pastryInit(numNodes-1)
  end

  def spawnProcess(nodeCounter) do
    nodeId = :md5
            |> :crypto.hash(to_string(nodeCounter)) 
            |> Base.encode16() 
            |> String.to_atom
    #initialize states
    leafSet = States.initLeafSet(@b)
    routingTable = States.initRoutingTable(@b)
    neighborSet = States.initNeighborsSet(@b)
    {:ok, pid} = GenServer.start(__MODULE__, :createdNode, name: nodeId)
    #nodeId = :md5 |> :crypto.hash(:erlang.pid_to_list(pid)) |> Base.encode16() 
    :global.register_name(nodeId, pid)
    newNode = nodeId
  end

  def init(state) do
    {:ok, state}
  end

  #new node sends join to nearest node
  def sendJoin(newNode, nearbyNode) do
    #IO.inspect :global.registered_names
    GenServer.cast(newNode, {:joinNetwork, nearbyNode, newNode})
  end

  #new node sends :join message to "assumed" nearby node
  def handle_cast({:joinNetwork, nearbyNode, newNode}, currentState) do
    GenServer.cast(nearbyNode, {:join, newNode})
    { :noreply, :joinedNetwork}
  end
  #nearby node selected by the new node receives the join message
  def handle_cast({:join, key}, curState) do
    #IO.puts key
    { :noreply, curState}
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
    Pastry.pastryInit(numNodes)
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
