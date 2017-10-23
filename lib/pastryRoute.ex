defmodule PastryRoute do
    use GenServer
    #routing algorithm
    def route(numHops, key, curr_genServer_name, {[leafSetLeft, leafSetRight], routingTable}) do
        {lLow, lHigh} = Enum.min_max(leafSetLeft++leafSetRight)
        #IO.inspect lLow
        #check for special case when leafest crosses over point 0 node ID
        cond do
            lLow > lHigh and ((key <= lLow and key <= lHigh) or (key >= lLow and key >= lHigh)) ->
                closestLeaf(leafSetRight++leafSetLeft, key) 
                |> String.to_atom
                |> GenServer.cast({:finalNode, numHops+1})
            key >= lLow and key <= lHigh ->
                closestLeaf(leafSetRight++leafSetLeft, key) 
                |> String.to_atom
                |> GenServer.cast({:finalNode, numHops+1, key})
            true ->
            #use the routing table
                name = curr_genServer_name
                #get length of prefix shared among and use it to access row of routing table
                l = name |> CommonPrefix.lcp(String.to_atom(key))
                #get value of l's digit in key
                dl = name |> Atom.to_string |> String.codepoints |> Enum.at(l)
                if Map.has_key?(routingTable, {l, dl}) do
                    routingTable 
                    |> Map.get({l, dl})
                    |> String.to_atom
                    |> GenServer.cast({:routing, curr_genServer_name, numHops+1, key})
                else
                    #rare case
                    allUnion = (leafSetLeft ++ leafSetRight ++ Map.values(routingTable))
                                |> Enum.uniq
                    nodeToRoute = rareCase(allUnion, l, name, key) 
                    cond do
                        nodeToRoute != [] ->
                            selectedNode = nodeToRoute
                                            |> Enum.random
                                            |> String.to_atom
                            selectedNode |> GenServer.cast({:routing, selectedNode, numHops+1, key})
                        true ->
                            IO.puts "can't go any further"
                    end
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
        a = name |> Atom.to_string |> Integer.parse(16) |> elem(0)
        d = key |> Integer.parse(16) |> elem(0)
        Enum.filter(allUnion, fn(x) ->
            abs((x |> Integer.parse(16) |> elem(0)) - d) < abs(a-d) and
            x |> String.to_atom |> CommonPrefix.lcp(String.to_atom(key)) >= l
        end)
    end
end