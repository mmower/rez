defmodule Rez.Parser.BTreeParserTest do
  use ExUnit.Case
  alias Rez.Parser.BTreeParser

  test "Parses simplest node" do
    src = "^[select]"
    parser = BTreeParser.bt_parser()
    %{status: :ok, ast: ast} = Ergo.parse(parser, src)
    {:btree, {:node, {"rez", "select"}, %{}, []}} = ast
  end

  test "Parses node with options" do
    src = "^[pselect {p: 25}]"
    parser = BTreeParser.bt_parser()
    %{status: :ok, ast: ast} = Ergo.parse(parser, src)
    {:btree, {:node, {"rez", "pselect"}, %{"p" => {:number, 25}}, []}} = ast
  end

  test "Parses a node with children" do
    src = "^[select [[choose {p: 25}] [choose {p: 50}]]]"
    parser = BTreeParser.bt_parser()
    %{status: :ok, ast: ast} = Ergo.parse(parser, src)
    {:btree, root_node} = ast
    {:node, {"rez", "select"}, %{}, children} = root_node
    [
      {:node, {"rez", "choose"}, %{"p" => {:number, 25}}, []},
      {:node, {"rez", "choose"}, %{"p" => {:number, 50}}, []}
    ] = children
  end

  test "Parses node with deeply nested children" do
    src = """
    ^[select [
      [choose {p: 25} [
        [my/dice {sides: 6 modifier: 1} [
          [my/dmod]]]]]
      [my/dice {sides: 8 modifier: 1}]]]
    """
    parser = BTreeParser.bt_parser()
    %{status: :ok, ast: {:btree, root_node}} = Ergo.parse(parser, src)
    {:node, {"rez", "select"}, %{}, root_children} = root_node
    [
      {:node, {"rez", "choose"}, %{"p" => {:number, 25}}, choose_children},
      {:node, {"my", "dice"}, %{"sides" => {:number, 8}, "modifier" => {:number, 1}}, []}
    ] = root_children
    [
      {:node, {"my", "dice"}, %{"sides" => {:number, 6}, "modifier" => {:number, 1}}, dice_children}
    ] = choose_children
    [
      {:node, {"my", "dmod"}, %{}, []}
    ] = dice_children
  end

end
