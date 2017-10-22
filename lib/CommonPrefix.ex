defmodule CommonPrefix do
  def lcp(nodeAtom1, nodeAtom2), do: Atom.to_string(nodeAtom1) |> lcp(Atom.to_string(nodeAtom2), 0)
  def lcp("", node2, index), do: index
  def lcp(node1, "", index), do: index
  def lcp("", "", index), do: index
  def lcp(node1, node2, index) do
    cond do
      String.at(node1, index) == String.at(node2, index) ->
        lcp(node1, node2, index+1)
      true ->
        lcp("", "", index)
    end
  end
end
