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
    nearbyNode |> pastryInit(numNodes-1)
  end

  def spawnProcess(nodeCounter) do
    nodeId = :md5
            |> :crypto.hash(to_string(nodeCounter))
            |> Base.encode16()
            |> String.to_atom
    #initialize empty states
    leafSet = [[],[]]
    routingTable = %{}
    neighborSet = []
    {:ok, pid} = GenServer.start(__MODULE__, {leafSet, routingTable, neighborSet}, name: nodeId)
    #nodeId = :md5 |> :crypto.hash(:erlang.pid_to_list(pid)) |> Base.encode16()
    :global.register_name(nodeId, pid)
    nodeId
  end

  def init(state) do
    #tell yourself to send a request every @interval
    #Process.send_after(self(), :sendRequest, @interval)
    {:ok, state}
  end

  #Instructs the newly created process/node to join Pastry network
  #This call is made from the main process
  def sendJoinPastry(newNode, nearbyNode) do
    #IO.inspect :global.registered_names
    #IO.inspect :sys.get_state(nearbyNode)
    GenServer.call(newNode, {:joinNetwork, newNode, nearbyNode})
  end

  #The very first node in the network receives join
  #def handle_call({:join, key}, _, {[], {}, []}), do: { :reply, :null, {[], {}, []}}

  #send request form this nod
  def handle_info({curr_genServer_name, :sendRequest}, curState) do
    key =  2 * :math.pow(2,@b) |> round |> Utils.perm_rep
    PastryRoute.route("wow", key, curr_genServer_name, curState)
    #Process.send_after(self(), :sendRequest, @interval)
    {:noreply, curState}
  end
  #receive the message as the final node
  def handle_cast({:finalNode, _, _}, curState) do
    IO.puts "reached final node"
    {:noreply, curState}
  end
  #receive the message to route it further
  def handle_cast({:routing, curr_genServer_name, message, key}, curState) do
    PastryRoute.route(message, key, curr_genServer_name, curState)
  end

  # new node sends :join message to "assumed" nearby node
  # 1. Receives state tables
  # 2. Send message to all nodes in routing table. These nodes will then update their states
  def handle_call({:joinNetwork, newNode, nearbyNode}, _, _) do
    #1
    received_state = GenServer.call(nearbyNode, {:join, newNode, nearbyNode})
    #2
    routing_table = received_state |> elem(1)
    routing_table
    |> Map.values()
    |> Enum.each(fn(nodeId)->
      #IO.inspect nodeId
      nodeId = nodeId |> String.to_atom
      GenServer.cast(nodeId, {:add_new_joined_node, newNode, nodeId})
    end)

    global_reg_to_list = :global.registered_names
    populated_map = PastryInitFunctions.populate_routing_table(routing_table, newNode, global_reg_to_list -- [newNode])
    routing_table = Map.merge(routing_table, populated_map)
    received_state = {elem(received_state, 0), routing_table, elem(received_state, 1)}

    {:reply, :joinedNetwork, received_state}
  end
  def handle_call({:join, key, curr_genServer_name}, _, currentState) do
    {leafSet, routingTable, neighborSet} = currentState
    #updated_currentState is not always updated. It is only update when there is only 1 node in network,
    #and some new node joins the network
    #Other updates to state(routing table), are performed in the end after newly joined node receives state tables
    [state_to_send, updated_currentState] = PastryInitFunctions.newJoin(currentState, curr_genServer_name, key)
    #Todo: neighborSet ? when do we pick from this
    {:reply, state_to_send, updated_currentState}
  end

  # Handled when you finally reach Z or the destination node
  # Leafset is a list of 2 lists lower and higher
  # returned_leafset -> reply to caller
  # modified_curr_node_leafset -> change to leafset of current node
  # Returns of type leafset
  def handle_call({:final_node, key, curr_genServer_name}, _, currentState) do
    #{curr_genServer_name, _} = GenServer.whereis(self())
    {leafSet,_,_} = currentState
    [ls_lower, ls_higher] =leafSet
    [returned_leafset, modified_curr_node_leafset] = PastryInitFunctions.finalNodeComp(ls_lower, ls_higher, key, curr_genServer_name)
    routingTable = elem(currentState, 1)
    neighborSet = elem(currentState, 2)
    currentState = {modified_curr_node_leafset, routingTable, neighborSet}
    {:reply, returned_leafset, currentState}
  end

  def handle_cast({:add_new_joined_node, key, curr_genServer_name}, currentState) do
      #{curr_genServer_name, _} = GenServer.whereis(self())
      row =  curr_genServer_name |> CommonPrefix.lcp(key)
      {col, _} = Atom.to_string(key) |> String.at(row) |> Integer.parse(16)
      routingTable = elem(currentState, 1)
      table_val = routingTable[{row, col}]
      value_to_update = cond do
        table_val == nil -> Atom.to_string(key)
        true -> Enum.random([table_val, key])
      end
      #inserts key, value if does not exist
      routingTable = Map.update(routingTable, {row, col}, value_to_update, fn(curr_val) -> value_to_update end)
      currentState = {elem(currentState, 0), routingTable, elem(currentState, 1)}
      {:noreply, currentState}
  end
end