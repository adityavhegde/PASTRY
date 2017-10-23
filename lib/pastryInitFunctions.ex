defmodule PastryInitFunctions do
    use GenServer
  #returns a routing table which should be merged with callers rotuing table
  @spec update_routing_table(routingTable :: map, newNode :: atom, global_reg :: list) :: map
  def update_routing_table(routingTable, newNode, global_reg) do
    #convert global_reg type, from atom to String
    global_reg_list = Enum.map(global_reg, fn(val)-> Atom.to_string(val) end)
    key = Atom.to_string(newNode)
    count = 0
    #if routing table is full or if list is empty, stop
    entries_to_fill = 512 - Map.size(routingTable)
    map_size = Map.size(routingTable)

    map_to_return =
    Enum.reduce(global_reg_list, %{}, fn(val, acc) ->
      cond do
        Map.size(acc) > entries_to_fill -> Map.merge(%{nil => nil}, acc)
        true ->
           row = CommonPrefix.lcp(String.to_atom(val), String.to_atom(key))
           {col, _} = val |> String.at(row) |> Integer.parse(16)
           val_to_put = cond do
             Map.has_key?(routingTable,{row, col}) -> routingTable[{row, col}]
             true -> val
           end
           temp = %{{row, col}=>val_to_put}
           Map.merge(acc, temp)
      end
    end)
    #remove nils and return
    map_to_return
    |> Map.to_list
    |> Enum.reject(fn(tup) -> elem(tup, 0) == nil end)
    |> Enum.into(%{})
  end

  def update_leafSet(leafSet, newNode) do
    global_reg = :global.registered_names |> Enum.sort
    nodePos = Enum.find_index(global_reg, fn(x) -> x == newNode end)
    ls_lower = Enum.slice(global_reg, max(0, nodePos-16), nodePos+1) 
              |> Enum.map(fn(x) -> x |> Atom.to_string end)
    ls_higher = Enum.slice(global_reg, nodePos+1, min(nodePos+17, Enum.count(global_reg)+1)) 
              |> Enum.map(fn(x) -> x |> Atom.to_string end)
    [ls_lower, ls_higher]
  end
end