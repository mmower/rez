defmodule Rez.Parser.AliasParsesTest do
  use ExUnit.Case
  import Rez.Parser.AliasParsers
  alias Rez.AST.NodeHelper
  import Rez.Utils, only: [dummy_source: 1]

  test "parse empty alias definition" do
    input = """
    @elem standard_scene = scene
    """

    source = dummy_source(input)
    ctx = Ergo.parse(alias_directive(), input, data: %{source: source, aliases: %{}})

    assert %{
             status: :ok,
             data: %{aliases: %{"standard_scene" => {"scene", {:mixins, []}}}}
           } = ctx
  end

  test "parse alias definition with parents" do
    input = """
    @elem standard_scene = scene<#foo, #bar>
    """

    source = dummy_source(input)

    assert %{status: :ok, data: %{aliases: aliases}} =
             Ergo.parse(alias_directive(), input, data: %{source: source, aliases: %{}})

    assert %{
             "standard_scene" => {"scene", {:mixins, [{:elem_ref, "foo"}, {:elem_ref, "bar"}]}}
           } = aliases
  end

  test "parse alias use" do
    input = """
    @ring magic_ring {
      magic: true
    }
    """

    source = dummy_source(input)

    assert %{status: :ok, ast: ast} =
             Ergo.parse(aliased_element(), input,
               data: %{
                 id_map: %{},
                 source: source,
                 aliases: %{"ring" => {"item", {:mixins, [{:elem_ref, "ring"}]}}}
               }
             )

    assert %Rez.AST.Item{id: "magic_ring"} = ast
    assert %Rez.AST.Attribute{value: true} = NodeHelper.get_attr(ast, "magic")
    assert %Rez.AST.Attribute{value: [{:elem_ref, "ring"}]} = NodeHelper.get_attr(ast, "$mixins")
  end

  # test "parse merges default & defined tags" do
  #   input = """
  #   @class warlord begin
  #     tags: \#{:combat_class}
  #   end
  #   """

  #   source = dummy_source(input)

  #   aliases = %{
  #     "class" =>
  #       {"object",
  #        %{
  #          "tags" => %Attribute{
  #            name: "tags",
  #            type: :set,
  #            value: MapSet.new([{:keyword, "class"}])
  #          }
  #        }}
  #   }

  #   assert %{status: :ok, ast: ast} =
  #            Ergo.parse(alias_block(), input,
  #              data: %{source: source, aliases: aliases, id_map: %{}}
  #            )

  #   assert %Object{
  #            id: "warlord",
  #            attributes: %{
  #              "tags" => tags_attr
  #            }
  #          } = ast

  #   assert %{name: "tags", type: :set, value: tags} = tags_attr
  #   assert MapSet.member?(tags, {:keyword, "class"})
  #   assert MapSet.member?(tags, {:keyword, "combat_class"})
  # end
end
