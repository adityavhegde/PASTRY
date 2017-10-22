defmodule PastryInit do
@b 4
@interval 1000  #1 request/second
use GenServer
  def pastryInit(numNodes) do
    #when the first node joins Pastry
    newNode = spawnProcess(numNodes)
    newNode |> pastryInit(numNodes-1)
  end
  #spawning actors
  def pastryInit(_, 0), do: true
  def pastryInit(nearbyNode, numNodes) do
    #new process gets the name of its previous process
    #assumption: the newly spawned process is closer to the previously spawned
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
    nodeId
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

  #The very first node in the network receives join
  #def handle_call({:join, key}, _, {[], {}, []}), do: { :reply, :null, {[], {}, []}}

  #send request form this nod
  def handle_info(:sendRequest, curState) do
    key =  2 * :math.pow(2,@b) |> round |> Utils.perm_rep
    PastryRoute.route("wow", key, curState)
    Process.send_after(self(), :sendRequest, @interval)
    {:noreply, curState}
  end
  #send request form this node
  #def handle_cast(:sendRequest, curState) do
  #  key =  2 * :math.pow(2,@b) |> round |> Utils.perm_rep
  #  PastryRoute.route("wow", key, curState)
  #  {:noreply, curState}
  #end
  #receive the message as the final node
  def handle_cast({:finalNode, _, _}, curState) do
    IO.puts "reached final node"
    {:noreply, curState}
  end
  #receive the message to route it further
  def handle_cast({:routing, message, key}, curState) do
    PastryRoute.route(message, key, curState)
  end

  # new node sends :join message to "assumed" nearby node
  # 1. Receives state tables
  # 2. Send message to all nodes in routing table. These nodes will then update their states
  def handle_call({:joinNetwork, nearbyNode, newNode}, _, _) do
    #1
    received_state_tables = GenServer.call(nearbyNode, {:join, newNode})
    #2
    received_state_tables |> elem(1) |> Map.keys() |> Enum.each(fn{map_key}->
      received_state_tables[map_key] |> GenServer.cast({:add_new_joined_node, newNode})
    end)

    {:reply, :joinedNetwork, received_state_tables}
  end
  def handle_call({:join, key}, _, currentState) do
    {leafSet, routingTable, neighborSet} = currentState

    #returned_val can be a map(routing table) or a list(leafSet, neighborSet)
    state_to_send = cond do
      Enum.count(leafSet) == 0 ->
        {curr_genServer_name, _} = GenServer.whereis(self())
        returned_leafset = curr_genServer_name |> GenServer.call({:final_node, key})
        {returned_leafset, %{}, []}
      #Todo: IMP correct this condition
       Atom.to_string(key) <= Enum.max(leafSet) and Atom.to_string(key) >= Enum.min(leafSet) ->
        returned_leafset = PastryRoute.closestLeaf(leafSet, key)
                             |> GenServer.call({:final_node, key})
                             |> elem(0)

         {returned_leafset, %{}, []}
      true ->
        # Go to routing table
        # Returns a state
        {curr_genServer_name, _} = GenServer.whereis(self())
        row =  CommonPrefix.lcp(curr_genServer_name, key)
        {col, _} = Atom.to_string(key) |> String.at(row + 1) |> Integer.parse(16)

        val_at_map = routingTable |> Map.get({row, col})

        # returned_routing_table
        # Route the received call
        # If no entry exists in the routing table, stop at this node by returning leafset
        returned_state = cond do
          val_at_map == nil ->
            ls  = GenServer.call(curr_genServer_name, {:final_node, key})
            [ls, %{}, neighborSet]
          true ->
            #pick nth row
            returned_routing_table = GenServer.call(val_at_map, {:join, key}) |> elem(1)

            curr_gen_s_routing_rows
              = routingTable
                |> Map.keys()
                |> Enum.reduce(%{}, fn({key_a, key_b}, acc) ->
                    cond do
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
              [leafSet, temp, neighborSet]
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
  def handle_call({:final_node, key}, _, currentState) do
    [ls_lower, ls_higher] = elem(currentState, 0)
    {curr_genServer_name, _} = GenServer.whereis(self())

    [returned_leafset, modified_curr_node_leafset] =
      cond do
         #Todo: IMP! write a function to do this
        Atom.to_string(key) < Atom.to_string(curr_genServer_name) ->
          returned_ls_higher = Enum.slice(ls_higher, 0, 15) ++ [curr_genServer_name]|> Enum.sort()
          ret = cond do
            Enum.count(ls_lower) == 16 -> tl(ls_lower) ++ [Atom.to_string(key)] |> Enum.sort()
            Enum.count(ls_lower) < 16 -> ls_lower ++ [Atom.to_string(key)] |> Enum.sort()
          end
          [[ls_lower, returned_ls_higher], [ret, ls_higher]]

        Atom.to_string(key) > Atom.to_string(curr_genServer_name) ->
          [returned_ls_lower, ret] = cond do
            Enum.count(ls_lower) == 16 ->
              left = Enum.slice(ls_lower, 1, 16) ++ [curr_genServer_name]|> Enum.sort()
              right = (ls_higher -- Enum.at(ls_higher,15)) ++ [Atom.to_string(key)]|> Enum.sort()
              [left, right]

            Enum.count(ls_lower) < 16 ->
              left = ls_lower ++ [curr_genServer_name]|> Enum.sort()
              right = ls_higher ++ [Atom.to_string(key)]|> Enum.sort()
              [left, right]
          end
          [[returned_ls_lower, ls_higher], [ls_lower, ret]]
      end

      routingTable = elem(currentState, 1)
      neighborSet = elem(currentState, 2)

      currentState = {modified_curr_node_leafset, routingTable, neighborSet}

    {:reply, returned_leafset, currentState}
  end

  def handle_cast({:add_new_joined_node, key}, _, currentState) do
      {curr_genServer_name, _} = GenServer.whereis(self())

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
