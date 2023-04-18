defmodule Rez.Parser.ParentObjectTest do
  use ExUnit.Case
  import Rez.Parser.StructureParsers

  test "parses single parent" do
    parser = parent_objects()
    source = "<foo>"

    assert %{status: :ok, ast: ast} = Ergo.parse(parser, source)
    assert {:base, [:foo]} = ast
  end

  test "parses multiple parents" do
    parser = parent_objects()
    source = "<foo, bar,baz,  qux >"

    assert %{status: :ok, ast: ast} = Ergo.parse(parser, source)
    assert {:base, [:foo, :bar, :baz, :qux]} = ast
  end
end
