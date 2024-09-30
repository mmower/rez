defmodule Rez.Parser.BTreeParserTest do
  use ExUnit.Case
  alias Rez.Parser.BTreeParser

  test "Parses empty tree" do
    src = "^[]"
    parser = BTreeParser.bt_parser()
    %{status: :ok, ast: {:bht, {:empty, %{}, []}}} = Ergo.parse(parser, src)
  end

  test "Parses simplest node" do
    src = "^[b_select]"
    parser = BTreeParser.bt_parser()
    %{status: :ok, ast: ast} = Ergo.parse(parser, src)
    {:bht, {"b_select", %{}, []}} = ast
  end

  test "Parses bare node with whitespace" do
    parser = BTreeParser.bt_parser()
    %{status: :ok} = Ergo.parse(parser, "^[ b_select]")
    %{status: :ok} = Ergo.parse(parser, "^[b_select ]")
  end

  test "Parses node with options" do
    src = "^[b_pselect p=25]"
    parser = BTreeParser.bt_parser()
    %{status: :ok, ast: ast} = Ergo.parse(parser, src)
    {:bht, {"b_pselect", %{"p" => {:number, 25}}, []}} = ast
  end

  test "Parses node with a child" do
    src = "^[b_invert [b_always]]"
    parser = BTreeParser.bt_parser()
    %{status: :ok, ast: ast} = Ergo.parse(parser, src)
    {:bht, {"b_invert", %{}, [child]}} = ast
    {"b_always", %{}, []} = child
  end

  test "Parses a node with two children" do
    src = "^[b_select [b_random_quote p=25] [b_random_quote p=50]]"
    parser = BTreeParser.bt_parser()
    %{status: :ok, ast: ast} = Ergo.parse(parser, src)
    {:bht, root_node} = ast
    {"b_select", %{}, children} = root_node

    [
      {"b_random_quote", %{"p" => {:number, 25}}, []},
      {"b_random_quote", %{"p" => {:number, 50}}, []}
    ] = children
  end

  test "Parses node with deeply nested children" do
    src = """
    ^[b_select [b_choose p=25 [b_dice_roll sides=6 modifier=1 [b_dmod]]] [b_dice_roll sides=8 modifier=1]]
    """

    parser = BTreeParser.bt_parser()
    %{status: :ok, ast: {:bht, root_node}} = Ergo.parse(parser, src)
    {"b_select", %{}, root_children} = root_node

    [
      {"b_choose", %{"p" => {:number, 25}}, choose_children},
      {"b_dice_roll", %{"sides" => {:number, 8}, "modifier" => {:number, 1}}, []}
    ] = root_children

    [
      {"b_dice_roll", %{"sides" => {:number, 6}, "modifier" => {:number, 1}}, dice_children}
    ] = choose_children

    [
      {"b_dmod", %{}, []}
    ] = dice_children
  end
end
