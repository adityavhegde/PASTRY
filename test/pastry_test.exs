defmodule PastryTest do
  use ExUnit.Case
  import CommonPrefix
  doctest Pastry

<<<<<<< HEAD
  test "gets closest nodeId from leafset" do
    a = :md5 |> :crypto.hash(to_string(1)) |> Base.encode16() #"C4CA4238A0B923820DCC509A6F75849B"
    b = :md5 |> :crypto.hash(to_string(3)) |> Base.encode16() #"ECCBC87E4B5CE2FE28308FD9F2A7BAF3"
    c = :md5 |> :crypto.hash(to_string(4)) |> Base.encode16() #"A87FF679A2F3E71D9181A67B7542122C"
    key = :md5 |> :crypto.hash(to_string(2)) |> Base.encode16() #"C81E728D9D4C2F636F067F89CC14862C"
    leafSet = [a,b,c]
    assert PastryRoute.closestLeaf(leafSet, key) == a 
    IO.puts "getting closestNodeId from leafset succesfully"
=======
  test "common prefixe: find a common prefix for two normal strings" do
    assert CommonPrefix.lcp(:"drag", :"drop") == 2
  end

  test "common prefix: node1 is empty" do
    assert CommonPrefix.lcp(:"", :"hiil") == 0
  end

  test "common prefix: node2 is empty" do
    assert CommonPrefix.lcp(:"hii", :"") == 0
  end

  test "common prefix: nothing matches" do
    assert CommonPrefix.lcp(:"cii", :"hiil") == 0
  end

  test "commin prefix: both strings are empty" do
    assert CommonPrefix.lcp(:"", :"") == 0
>>>>>>> 3ad0ec2a1de52c1b1dcd5e7660479d12774a0748
  end
end
