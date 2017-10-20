defmodule PastryInit do
@b 4
use GenServer
  #spawning actors
  def pastryInit(_, 0), do: true

  #when the first node joins Pastry
  def pastryInit(numNodes) do
    newNode = spawnProcess(numNodes)
    newNode |> pastryInit(numNodes-1)
  end

  #new process gets the name of its previous process
  #assumption: the newly spawned process is closer to the previously spawned
  def pastryInit(nearbyNode, numNodes) do
    newNode = spawnProcess(numNodes)
    sendJoinPastry(newNode, nearbyNode)
    newNode |> pastryInit(numNodes-1)
  end

  def spawnProcess(nodeCounter) do
    nodeId = :md5
            |> :crypto.hash(to_string(nodeCounter))
            |> Base.encode16()
            |> String.to_atom
    #initialize empty states
    leafSet = States.initLeafSet(@b)
    routingTable = States.initRoutingTable(@b)
    neighborSet = States.initNeighborsSet(@b)
    {:ok, pid} = GenServer.start(__MODULE__, {leafSet, routingTable, neighborSet}, name: nodeId)
    #nodeId = :md5 |> :crypto.hash(:erlang.pid_to_list(pid)) |> Base.encode16()
    :global.register_name(nodeId, pid)
    newNode = nodeId
  end

  def init(state) do
    {:ok, state}
  end

  #Instructs the newly created process/node to join Pastry network
  def sendJoinPastry(newNode, nearbyNode) do
    #IO.inspect :global.registered_names
    #GenServer.call is similar to -> send pid, #stuff
    #pid here is newNode
    GenServer.call(newNode, {:joinNetwork, nearbyNode, newNode})
  end

  #new node sends :join message to "assumed" nearby node
  def handle_call({:joinNetwork, nearbyNode, newNode}, from, currentState) do
    GenServer.call(nearbyNode, {:join, newNode})
    { :noreply, :joinedNetwork}
  end
  #nearby node selected by the new node receives the join message
  def handle_call({:join, key}, from, curState) do
    #Todo

    { :noreply, curState}
  end
end
