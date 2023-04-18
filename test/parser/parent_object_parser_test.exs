defmodule Rez.Parser.ParentObjectTest do
  use ExUnit.Case
  import Rez.Parser.StructureParsers

  test "parses single parent" do
    parser = parent_objects()
    source = "<foo>"

    assert %{status: :ok, ast: ast} = Ergo.parse(parser, source)
    assert {:parent_objects, [{:keyword, :foo}]} = ast
  end

  test "parses multiple parents" do
    parser = parent_objects()
    source = "<foo, bar,baz,  qux >"

    assert %{status: :ok, ast: ast} = Ergo.parse(parser, source)

    assert {:parent_objects,
            [{:keyword, :foo}, {:keyword, :bar}, {:keyword, :baz}, {:keyword, :qux}]} = ast
  end
end
