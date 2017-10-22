defmodule PastryInit do
@b 4
@interval 1000  #1 request/second
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
    #tell yourself to send a request every @interval
    Process.send_after(self(), :sendRequest, @interval)
    {:ok, state}
  end

  #Instructs the newly created process/node to join Pastry network
  #This call is made from the main process
  def sendJoinPastry(newNode, nearbyNode) do
    #IO.inspect :global.registered_names
    GenServer.call(newNode, {:joinNetwork, nearbyNode, newNode})
  end

  #new node sends :join message to "assumed" nearby node
  def handle_call({:joinNetwork, nearbyNode, key}, from, currentState) do
    {leafSet, routingTable, neighborSet} = GenServer.call(nearbyNode, {:join, key})

    Enum.each(routingTable, fn{map_key, map_val}->
      routingTable[map_key] |> GenServer.cast({:add_new_joined_node, key})
    end)

    {:reply, :joinedNetwork, currentState} #Todo: change this
  end

  #The very first node in the network receives join
  def handle_call({:join, key}, from, {[], {}, []}), do: { :reply, :null, {[], {}, []}}

  #send request form this nod
  def handle_info(:sendRequest, curState) do
    key =  2 * :math.pow(2,@b) |> round |> Utils.perm_rep
    PastryRoute.route("wow", key, curState)
    Process.send_after(self(), :sendRequest, @interval)
    {:noreply, curState}
  end
  #send request form this node
  def handle_cast(:sendRequest, curState) do
    key =  2 * :math.pow(2,@b) |> round |> Utils.perm_rep
    PastryRoute.route("wow", key, curState)
    {:noreply, curState}
  end
  #receive the message as the final node
  def handle_cast({:finalNode, message, key}, curState) do
    IO.puts "reached final node"
    {:noreply, curState}
  end
  #receive the message to route it further
  def handle_cast({:routing, message, key}, curState) do
    PastryRoute.route("wow", key, curState)
  end
  
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

         {leafSet, routingTable, neighborSet}
      true ->
        #Go to routing table
        #return a tuple with {key1, key2, val}
        {curr_genServer_name, node} = GenServer.whereis(self)
        row =  CommonPrefix.lcp(curr_genServer_name, key)
        {col, garbage} = Atom.to_string(key) |> String.at(row + 1) |> Integer.parse(16)

        val_at_map = routingTable |> Map.get({row, col})

        #returned_routing_table
        returned_state = cond do
          val_at_map == nil ->
            ls  = GenServer.call(curr_genServer_name, {:final_node, key})
            [ls, routingTable, neighborSet]
          true ->
            #pick nth row
            returned_routing_table = routingTable
                |> Map.keys()
                |> Enum.reduce(%{}, fn({key_a, key_b}, acc) ->
                  candidate_row = cond do
                      key_a == row ->
                          temp_map = %{{key_a, key_b} => routingTable[{key_a, key_b}]}
                          acc = Map.merge(temp_map, acc)
                      true -> true
                    end
                end)
              [leafSet, routingTable, neighborSet]
        end

        #merge returned_routing_table into routingTable
        #Todo: test if this merge works fine

        routingTable = Map.merge(routingTable, returned_state |> elem(1))
        {leafSet, routingTable, neighborSet}
    end
    #Todo: neighborSet ? when do we pick from this

    { :reply, state_to_send, currentState}
  end

  # Handled when you finally reach Z or the destination node
  # Leafset is a list of 2 lists lower and higher
  # returned_leafset -> reply to caller
  # modified_curr_node_leafset -> change to leafset of current node
  def handle_call({:final_node, key}, from, currentState) do
    [ls_lower, ls_higher] = elem(currentState, 0)
    {curr_genServer_name, node} = GenServer.whereis(self)

    [returned_leafset, modified_curr_node_leafset] =
      cond do
         #Todo: IMP! write a function to do this
        key < curr_genServer_name ->
          returned_ls_higher = Enum.slice(ls_higher, 0, 15) ++ [curr_genServer_name]
          ret = cond do
            Enum.count(ls_lower) == 16 -> tl(ls_lower) ++ [Atom.to_string(key)]
            Enum.count(ls_lower) < 16 -> ls_lower + [Atom.to_string(key)]
          end
          [[ls_lower, returned_ls_higher], [ret, ls_higher]]

        key > curr_genServer_name ->
          [returned_ls_lower, ret] = cond do
            Enum.count(ls_lower) == 16 ->
              [Enum.slice(ls_lower, 1, 15) ++ [curr_genServer_name], ls_higher -- Enum.at(ls_higher, 15) ++ [Atom.to_string(key)]]

            Enum.count(ls_lower) < 16 ->
              [ls_lower ++ [curr_genServer_name], ls_higher ++ [Atom.to_string(key)]]
          end
          [[returned_ls_lower, ls_higher], [ls_lower, ret]]
      end

      routingTable = elem(currentState, 1)
      neighborSet = elem(currentState, 2)

      currentState = {modified_curr_node_leafset, routingTable, neighborSet}

    {:reply, returned_leafset, currentState}
  end

  def handle_cast({:add_new_joined_node, key}, from, currentState) do
      curr_genServer_name = self |> GenServer.whereis
      row =  CommonPrefix.lcp(curr_genServer_name, key)
      {col, garbage} = Atom.to_string(key) |> String.at(row + 1) |> Integer.parse(16)

      routingTable = elem(currentState, 1)
      table_val = routingTable[{row, col}]

      value_to_update = cond do
        table_val == nil -> key
        true -> Enum.random([table_val, key])
      end

      #Type conversion to string
      value_to_update = Atom.to_string(value_to_update)

      #inserts key, value if does not exist
      routingTable = Map.update(routingTable, {row, col}, value_to_update, fn(curr_val) -> value_to_update end)
      currentState = {elem(currentState, 0), routingTable, elem(currentState, 1)}

      {:noreply, currentState}
  end
end
