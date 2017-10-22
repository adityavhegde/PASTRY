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

  # new node sends :join message to "assumed" nearby node
  # 1. Receives state tables
  # 2. Send message to all nodes in routing table. These nodes will then update their states
  def handle_call({:joinNetwork, nearbyNode, newNode}, from, currentState) do
    #1
    received_state_tables = GenServer.call(nearbyNode, {:join, newNode})
    #2
    received_state_tables |> elem(1) |> Map.keys() |> Enum.each(fn{map_key}->
      routingTable[map_key] |> GenServer.cast({:add_new_joined_node, newNode})
    end)

    {:reply, :joinedNetwork, received_state_tables} #Todo: change this
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
        returned_leafset = PastryRoute.closestLeaf(leafSet, key)
                             |> GenServer.call({:final_node, key})
                             |> elem(0)

         {returned_leafset, %{}, []}
      true ->
        # Go to routing table
        # Returns a state
        {curr_genServer_name, node} = GenServer.whereis(self)
        row =  CommonPrefix.lcp(curr_genServer_name, key)
        {col, garbage} = Atom.to_string(key) |> String.at(row + 1) |> Integer.parse(16)

        val_at_map = routingTable |> Map.get({row, col})

        # returned_routing_table
        # Route the received call
        # If no entry exists in the routing table, stop at this node by returning leafset
        returned_state = cond do
          val_at_map == nil ->
            ls  = Genserver.call(curr_genServer_name, {:final_node, key})
            [ls, %{}, neighborSet]
          true ->
            #pick nth row
            returned_routing_table = Genserver.call(val_at_map, {:join, key}) |> elem(1)

            curr_gen_s_routing_rows
              = routingTable
                |> Map.keys()
                |> Enum.reduce(%{}, fn({key_a, key_b}, acc) ->
                  candidate_row = cond do
                      key_a == row ->
                          temp_map = %{{key_a, key_b} => routingTable[{key_a, key_b}]}
                          acc = Map.merge(temp_map, acc)
                      true -> acc = Map.merge(%{nil => nil}, acc)
                    end
                end)

              curr_gen_s_routing_rows =
                curr_gen_s_routing_rows
                |> Map.to_list
                |> Enum.reject(fn(tup) -> elem(tup, 0) == nil end)
                |> Enum.into(%{})

              temp = Map.merge(returned_routing_table, curr_gen_s_routing_rows)
              [leafset, temp, neighborSet]
        end #end of returned_state cond-do
    end #end of state_to_send cond-do

    #Todo: neighborSet ? when do we pick from this

    {:reply, state_to_send, currentState}
  end

  # Handled when you finally reach Z or the destination node
  # Leafset is a list of 2 lists lower and higher
  # returned_leafset -> reply to caller
  # modified_curr_node_leafset -> change to leafset of current node
  # Returns of type leafset
  def handle_call({:final_node, key}, from, currentState) do
    [ls_lower, ls_higher] = elem(currentState, 0)
    {curr_genServer_name, _} = GenServer.whereis(self)

    [returned_leafset, modified_curr_node_leafset] =
      cond do
         #Todo: IMP! write a function to do this
        Atom.to_string(key) < Atom.to_string(curr_genServer_name) ->
          returned_ls_higher = Enum.slice(ls_higher, 0, 15) ++ [curr_genServer_name]
          ret = cond do
            Enum.count(ls_lower) == 16 -> tl(ls_lower) ++ [Atom.to_string(key)]
            Enum.count(ls_lower) < 16 -> ls_lower ++ [Atom.to_string(key)]
          end
          [[ls_lower, returned_ls_higher], [ret, ls_higher]]

        Atom.to_string(key) > Atom.to_string(curr_genServer_name) ->
          [returned_ls_lower, ret] = cond do
            Enum.count(ls_lower) == 16 ->
              [Enum.slice(ls_lower, 1, 16) ++ [curr_genServer_name], (ls_higher -- Enum.at(ls_higher,15)) ++ [Atom.to_string(key)]]

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
      {curr_genServer_name, _} = GenServer.whereis(self)

      row =  CommonPrefix.lcp(curr_genServer_name, key)
      {col, _} = Atom.to_string(key) |> String.at(row + 1) |> Integer.parse(16)

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
