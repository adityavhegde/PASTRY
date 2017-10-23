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
    spawnProcess(numNodes)
    #sendJoinPastry(newNode, nearbyNode)
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
    {:ok, pid} = GenServer.start(__MODULE__, {leafSet, routingTable}, name: nodeId)
    :global.register_name(nodeId, pid)
    nodeId
  end

  def init(state) do
    #tell yourself to send a request every @interval
    #Process.send_after(self(), :sendRequest, @interval)
    {:ok, state}
  end

  def handle_info({_, _, 0}, curState) do
    {:noreply, curState}
  end
  #send request form this nod
  def handle_info({curr_genServer_name, :sendRequest, numRequests}, curState) do
    key =  2 * :math.pow(2,@b) |> round |> Utils.perm_rep
    numHops = 0
    PastryRoute.route(numHops, key, curr_genServer_name, curState)
    Process.send_after(curr_genServer_name, {curr_genServer_name, :sendRequest, numRequests-1}, @interval)
    {:noreply, curState}
  end
  
  #receive the message as the final node
  def handle_cast({:finalNode, numHops, _}, curState) do
    IO.puts "reached final node"
    IO.puts numHops
    {:noreply, curState}
  end
  #receive the message to route it further
  def handle_cast({:routing, curr_genServer_name, message, key}, curState) do
    PastryRoute.route(message, key, curr_genServer_name, curState)
    {:noreply, curState}
  end

  #call to update the leafset and routing table
  def handle_call({:update, newNode}, _, curState) do
    {leafSet, routingTable} = curState
    populated_map = PastryInitFunctions.update_routing_table(routingTable, newNode, :global.registered_names -- [newNode])
    routingTable = Map.merge(routingTable, populated_map)

    populatedLeafSet = PastryInitFunctions.update_leafSet(leafSet, newNode)
    newState = {populatedLeafSet, routingTable}
    {:reply, :updatedState, newState}
  end
end