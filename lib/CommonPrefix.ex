defmodule CommonPrefix do
  def lcp(nodeAtom1, nodeAtom2), do: Atom.to_string(nodeAtom1) |> lcp(Atom.to_string(nodeAtom2), 0, "")
  def lcp("", node2, index, result), do: result |> String.length
  def lcp(node1, "", index, result), do: result |> String.length
  def lcp("", "", index, result), do: result |> String.length
  def lcp(node1, node2, index, result) do
    cond do
      String.at(node1, index) == String.at(node2, index) ->
        lcp(node1, node2, index+1, [result, node1 |> String.at(index)] |> Enum.join(""))
      true ->
        lcp("", "", index, result)
    end
  end
end
