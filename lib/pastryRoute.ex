defmodule PastryRoute do
    use GenServer
    #routing algorithm
    def route(message, key, curr_genServer_name, {[leafSetLeft, leafSetRight], routingTable, neighborSet}) do
        #IO.puts [message, key]
        #IO.inspect leafSetLeft
        #IO.inspect leafSetRight
        #lLow = Enum.min(leafSetRight)
        #lHigh = Enum.max(leafSetLeft)
        {lLow, lHigh} = Enum.min_max(leafSetLeft++leafSetRight)
        #check for special case when leafest crosses over point 0 node ID
        cond do 
            lLow > lHigh and ((key <= lLow and key <= lHigh) or (key >= lLow and key >= lHigh)) ->
                closestLeaf(leafSetRight++leafSetLeft, key) 
                |> String.to_atom
                |> GenServer.cast({:finalNode, message})
            key >= lLow and key <= lHigh ->
                closestLeaf(leafSetRight++leafSetLeft, key) 
                |> String.to_atom
                |> GenServer.cast({:finalNode, message, key})
            true ->
            #use the routing table
                #{name, _} = GenServer.whereis(self())
                name = curr_genServer_name
                #get length of prefix shared among and use it to access row of routing table
                l = name |> CommonPrefix.lcp(String.to_atom(key))
                #get value of l's digit in key
                dl = name |> Atom.to_string |> String.codepoints |> Enum.at(l)
                if Map.has_key?(routingTable, {l, dl}) do
                    routingTable 
                    |> Map.get({l, dl})
                    |> String.to_atom
                    |> GenServer.cast({:routing, curr_genServer_name, message, key})
                else 
                    IO.puts "nothing found"
                    #rare case
                    #allUnion = (leafSetLeft ++ leafSetRight ++ Map.values(routingTable) ++ neighborSet)
                    #            |> Enum.uniq
                    #rareCase(allUnion, l, name, key) 
                    #|> Enum.random
                    #|> String.to_atom
                    #|> GenServer.cast({:routing, message})
                end
        end
    end

    #function to find closest leaf, if taking node from leafSet
    def closestLeaf(leafSet, key) do
        Enum.min_by(leafSet, fn(x) -> 
           ((x |> Integer.parse(16) |> elem(0)) - (key |> Integer.parse(16) |> elem(0))) 
           |> abs
        end)
    end

    def rareCase(allUnion, l, name, key) do
        a = name
        d = key |> Integer.parse(16) |> elem(0)
        Enum.filter(allUnion, fn(x) ->
            abs((x |> Integer.parse(16) |> elem(0)) - d) < abs(a-d) and
            x |> String.to_atom |> CommonPrefix.lcp(String.to_atom(key)) >= l
        end)
    end
end