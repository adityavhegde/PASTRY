defmodule PastryInitFunctions do
  #function to find final node
  def finalNodeComp(ls_lower, ls_higher, key, curr_genServer_name) do
    [returned_leafset, modified_curr_node_leafset] =
      cond do
         #Todo: IMP! write a function to do this
        Atom.to_string(key) < Atom.to_string(curr_genServer_name) ->
          returned_ls_higher = Enum.slice(ls_higher, 0, 15) ++ [Atom.to_string(curr_genServer_name)]|> Enum.sort()
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
  end

#function for joining new node to the network
  def newJoin(currentState, routingTable, neighborSet, curr_genServer_name, key) do
    [ls_lower, ls_higher] = elem(currentState, 0)

    cond do
      Enum.count(ls_lower) == 0 and Enum.count(ls_higher) == 0 ->
        row =  curr_genServer_name |> CommonPrefix.lcp(key)
        {col, _} = Atom.to_string(key) |> String.at(row) |> Integer.parse(16)
        map_key = {row, col}
        currentState = {[[Atom.to_string(key)],[Atom.to_string(key)]], elem(currentState,1), elem(currentState, 2)}

        state_to_send = {[[Atom.to_string(curr_genServer_name)],[Atom.to_string(curr_genServer_name)]],
                        %{map_key => Atom.to_string(curr_genServer_name)}, []}
        [state_to_send, currentState]
      #Todo: IMP correct this condition
      Atom.to_string(key) <= Enum.max(ls_higher) and Atom.to_string(key) >= Enum.min(ls_lower) ->
          returned_leafset = [ls_lower,ls_higher]
                            |>PastryRoute.closestLeaf(key)
                            |> GenServer.call({:final_node, key})
                            |> elem(0)
        state_to_send = {returned_leafset, %{}, []}
        [state_to_send, currentState]
      true ->
        # Go to routing table
        # Returns a state
        #{curr_genServer_name, _} = GenServer.whereis(self())
        row =  curr_genServer_name |> CommonPrefix.lcp(key)
        {col, _} = Atom.to_string(key) |> String.at(row) |> Integer.parse(16)

        val_at_map = routingTable |> Map.get({row, col})

        # returned_routing_table
        # Route the received call
        # If no entry exists in the routing table, stop at this node by returning leafset
        returned_state = cond do
          val_at_map == nil ->
            [ls,_]  = PastryInitFunctions.finalNodeComp(ls_lower, ls_higher, key, curr_genServer_name)
            #GenServer.call(curr_genServer_name, {:final_node, key, curr_genServer_name})
            # fix attempt: routing table
            val = Atom.to_string(key)
            {ls, %{{row, col}=> val}, neighborSet}
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
              [[[ls_lower],[ls_higher]], temp, neighborSet]
        end #end of returned_state cond-do
        [returned_state, currentState]
    end #end of state_to_send cond-do
  end
end
