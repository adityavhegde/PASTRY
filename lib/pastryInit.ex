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
    leafSet = []
    routingTable = %{}
    neighborSet = []
    {:ok, pid} = GenServer.start(__MODULE__, {leafSet, routingTable, neighborSet}, name: nodeId)
    #nodeId = :md5 |> :crypto.hash(:erlang.pid_to_list(pid)) |> Base.encode16()
    :global.register_name(nodeId, pid)
    newNode = nodeId
  end

  def init(state) do
    {:ok, state}
  end

  #Instructs the newly created process/node to join Pastry network
  #This call is made from the main process
  def sendJoinPastry(newNode, nearbyNode) do
    #IO.inspect :global.registered_names
    GenServer.call(newNode, {:joinNetwork, nearbyNode, newNode})
  end

  #new node sends :join message to "assumed" nearby node

  def handle_call({:joinNetwork, nearbyNode, newNode}, from, currentState) do
    {leafSet, routingTable, neighborSet} = GenServer.call(nearbyNode, {:join, newNode})
    #Todo: inform nodes in the stateTables that they need to change their states

    {:noreply, :joinedNetwork} #Todo: change this
  end

  #The very first node in the network receives join
  def handle_call({:join, key}, from, {[], {}, []}), do: { :reply, :null, {[], {}, []}}

  #nearby node selected by the new node receives the join message
  def handle_call({:join, key}, from, currentState) do
    {leafSet, routingTable, neighborSet} = currentState
    state_to_send = {}

    #Todo
    #if is in the leafset range-> route0
    lowest_leaf = leafSet |> Enum.min()
    highest_leaf = leafSet |> Enum.max()

    return_val = cond do
       Atom.to_string(key) <= highest_leaf and Atom.to_string(key) >= lowest_leaf ->
        index = PastryRoute.closestLeaf(leafSet, key)
        returned_leafset = Enum.at(leafSet, index) |>  GenServer.call({:final_node, key})

      true ->
        #Go to routing table
        #return a tuple with {key1, key2, val}
        {curr_genServer_name, node} = GenServer.whereis(self)
        row =  curr_genServer_name |> CommonPrefix.lcp(key)
        col = Atom.to_string(key) |> String.at(row + 1)
        returned_routing_table = routingTable
          |> Map.get({row, col})
          |> GenServer.call({:join, key})

      #Todo: select element; do a GenServer.call to that element
      #We expect genserver calls to return states

    end
    #else return the matching set from the routing table


    #Todo: send states to the calling process
    { :reply, state_to_send, currentState}
  end

  def handle_call({:final_node, key}, from, currentState) do
    #Todo: leafset configurations for key
  end
end
