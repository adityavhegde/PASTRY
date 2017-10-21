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
    

    {:reply, :joinedNetwork, currentState} #Todo: change this
  end

  #The very first node in the network receives join
  def handle_call({:join, key}, from, {[], {}, []}), do: { :reply, :null, {[], {}, []}}

  #nearby node selected by the new node receives the join message
  def handle_call({:join, key}, from, currentState) do
    {leafSet, routingTable, neighborSet} = currentState

    lowest_leaf =  Enum.min(leafSet)
    highest_leaf = Enum.max(leafSet)

    #returned_val can be a map(routing table) or a list(leafSet, neighborSet)
    state_to_send = cond do
      #Todo: IMP correct this condition
       Atom.to_string(key) <= highest_leaf and Atom.to_string(key) >= lowest_leaf ->
        index = PastryRoute.closestLeaf(leafSet, key)
        returned_leafset = leafSet
                             |> Enum.at(index)
                             |> GenServer.call({:final_node, key})
                             |> elem(0)

         {leafset, routingTable, neighborSet}
      true ->
        #Go to routing table
        #return a tuple with {key1, key2, val}
        {curr_genServer_name, node} = GenServer.whereis(self)
        row =  CommonPrefix.lcp(curr_genServer_name, key)
        {col, garbage} = Atom.to_string(key) |> String.at(row + 1) |> Integer.parse(16)
        returned_routing_table = routingTable
                                  |> Map.get({row, col})
                                  |> GenServer.call({:join, key})
                                  |> elem(1) #contains route map at this position

        #merge returned_routing_table into routingTable
        #Todo: test if this merge works fine
        routingTable = Map.merge(routingTable, returned_routing_table)
        {leafset, routingTable, neighborSet}
    end
    #Todo: neighborSet ? when do we pick from this

    { :reply, state_to_send, currentState}
  end

  #handled when you finally reach Z or the destination node
  #Leafset is a list of 2 lists lower and higher
  #returned_leafset -> reply to caller
  #modified_curr_node_leafset -> change to leafset of current node
  def handle_call({:final_node, key}, from, currentState) do
    [ls_lower, ls_higher] = elem(currentState, 0)
    {curr_genServer_name, node} = GenServer.whereis(self)

    returned_leafset, modified_curr_node_leafset =
      cond do
         #Todo: IMP! write a function to do this
        key < curr_genServer_name ->
          returned_ls_higher = Enum.slice(ls_higher, 0, 15) ++ [curr_genServer_name]
          ret = cond do
            Enum.count(ls_lower) == 16 -> tl(ls_lower) ++ [key]
            Enum.count(ls_lower) < 16 -> ls_lower + [key]
          end
          [ls_lower, returned_ls_higher], [ret, ls_higher]

        key > curr_genServer_name ->
          returned_ls_lower, ret = cond do
            Enum.count(ls_lower) == 16 ->
              Enum.slice(ls_lower, 1, 15) ++ [curr_genServer_name], ls_higher -- Enum.at(15) ++ [key]

            Enum.count(ls_lower) < 16 ->
              ls_lower ++ [curr_genServer_name], ls_higher ++ [key]
          end
          [returned_ls_lower, ls_higher], [ls_lower, ret]
      end

      routingTable = elem(currentState, 1)
      neighborSet = elem(currentState, 2)

      currentState = {modified_curr_node_leafset, routingTable, neighborSet}

    {:reply, returned_leafset, currentState}
  end
end
