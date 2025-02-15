defmodule Rez.Parser.MixinParserTest do
  use ExUnit.Case
  import Rez.Parser.StructureParsers

  test "parses single mixin" do
    parser = mixins()
    source = "<#foo>"

    assert %{status: :ok, ast: ast} = Ergo.parse(parser, source)
    assert {:mixins, [{:elem_ref, "foo"}]} = ast
  end

  test "parses multiple mixins" do
    parser = mixins()
    source = "<#foo, #bar,#baz,  #qux >"

    assert %{status: :ok, ast: ast} = Ergo.parse(parser, source)

    assert {:mixins,
            [{:elem_ref, "foo"}, {:elem_ref, "bar"}, {:elem_ref, "baz"}, {:elem_ref, "qux"}]} =
             ast
  end
end
