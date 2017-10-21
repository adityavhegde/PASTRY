defmodule PastryTest do
  use ExUnit.Case
  import CommonPrefix
  doctest Pastry

  test "common prefixe: find a common prefix for two normal strings" do
    assert CommonPrefix.lcp(:"drag", :"drop") == "dr"
  end

  test "common prefix: node1 is empty" do
    assert CommonPrefix.lcp(:"", :"hiil") == ""
  end

  test "common prefix: node2 is empty" do
    assert CommonPrefix.lcp(:"hii", :"") == ""
  end

  test "common prefix: nothing matches" do
    assert CommonPrefix.lcp(:"cii", :"hiil") == ""
  end

  test "commin prefix: both strings are empty" do
    assert CommonPrefix.lcp(:"", :"") == ""
  end
end
