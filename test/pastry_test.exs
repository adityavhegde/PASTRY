defmodule PastryTest do
  use ExUnit.Case
  import CommonPrefix
  doctest Pastry

  test "gets closest nodeId from leafset" do
    a = :md5 |> :crypto.hash(to_string(1)) |> Base.encode16() #"C4CA4238A0B923820DCC509A6F75849B"
    b = :md5 |> :crypto.hash(to_string(3)) |> Base.encode16() #"ECCBC87E4B5CE2FE28308FD9F2A7BAF3"
    c = :md5 |> :crypto.hash(to_string(4)) |> Base.encode16() #"A87FF679A2F3E71D9181A67B7542122C"
    key = :md5 |> :crypto.hash(to_string(2)) |> Base.encode16() #"C81E728D9D4C2F636F067F89CC14862C"
    leafSet = [a,b,c]
    assert PastryRoute.closestLeaf(leafSet, key) == a
    IO.puts "getting closestNodeId from leafset succesfully"
  end

  test "common prefix: find a common prefix for two normal strings" do
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
  end

  test "populate_routing_table returns correct entries" do
    key = :"200"
    routingTable = %{{1, 2} => "123", {2,3}=> "345"}
    global_reg_list = [:"201", :"202", :"203", :"221", :"231", :"256"]
    result = PastryInitFunctions.populate_routing_table(routingTable, key, global_reg_list)
    assert %{{1, 2} => "123", {1, 3} => "231", {1, 5} => "256", {2, 1} => "201", {2, 2} => "202", {2, 3} => "345"} == result
  end
end
