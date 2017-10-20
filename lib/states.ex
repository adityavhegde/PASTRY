defmodule States do
    def initLeafSet(b) do
        leafSetSize = 2 * :math.pow(2,b) |> round
        leafSet = :null |> Tuple.duplicate(leafSetSize)
    end

    def initRoutingTable(b) do
        #l is number of rows, i is no. of cloumns
        l = 2 * :math.pow(2,b) |> round
        i = :math.pow(2,b) |> round
        row = :null |> Tuple.duplicate(i)
        table = {row}
        createTable(table, l-1, i)
    end

    def createTable(table, 0, _) do
        table
    end
    def createTable(table, l, i) do
        row = :null |> Tuple.duplicate(i)
        table |> Tuple.append(row) |> createTable(l-1, i)
    end

    def initNeighborsSet(b) do
        initLeafSet(b)
    end
end