defmodule PastryRoute do
    use GenServer
    #routing algorithm
    def route(key, {[leafSetLeft, leafSetRight], routingTble, neighborSet}) do
        #TODO: uncomment the next line
        #{minLeaf, maxLeaf} = {0, 0}#Enum.min_max(leafSet)
        #check if key in range of leafSet
        #if minLeaf <= key and key <= maxLeaf  do
        if key >= Enum.min(leafSetRight) and key <= Enum.max(leafSetLeft)
            closestLeaf(leafSet, key) 
            |> Strin.to_atom
            |> GenServer.cast({:finalNode, message})
            IO.puts "true"
        else
        #use the routing table
            {name, _} = GenServer.whereis(pid)
            #get length of prefix shared among and use it to access row of routing table
            l = name |> CommonPrefix.lcp(String.to_atom(key))
            #get value of l's digit in key
            dl = name |> String.codepoints |> Enum.at(l)
            if Map.has_key?(routingTable, {l, dl}) do
                routingTable 
                |> Map.get({l, dl})
                |> String.to_atom
                |> GenServer.cast({:routing, message})
            else 
                #rare case
                allUnion = (leafSetLeft ++ leafSetRight ++ Map.values(routingTable) ++ neighborhoodSet)
                            |> Enum.uniq
                rareCase(l, name, key) 
                |> Enum.random
                |> String.to_atom
                |> GenServer.cast({:routing, message})
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

    def rareCase(l, name, key) do
        a = name
        d = key |> Integer.parse(16) |> elem(0)
        Enum.filter(rareCase, fn(x) ->
            abs(x |> Integer.parse(16) |> elem(0) -d) < abs(a-d) and
            x |> String.to_atom |> CommonPrefix.lcp(String.to_atom(key)) >= l
        end)
    end
end
