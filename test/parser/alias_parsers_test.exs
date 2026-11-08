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
             data: %{aliases: %{"standard_scene" => "scene"}}
           } = ctx
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
                 aliases: %{"ring" => "item"}
               }
             )

    assert %Rez.AST.Item{id: "magic_ring"} = ast
    assert %Rez.AST.Attribute{value: true} = NodeHelper.get_attr(ast, "magic")
  end

  test "parses @contains positions in an alias of @inventory" do
    input = """
    @chest strongbox {
      max_weight: 10
      @contains tray {
        slot_id: #ring_slot
        contents: [#coin]
      }
      @contains floor {
        slot_id: #ring_slot
      }
    }
    """

    assert %{status: :ok, ast: ast} =
             Ergo.parse(aliased_element(), input,
               data: %{
                 id_map: %{},
                 source: dummy_source(input),
                 aliases: %{"chest" => "inventory"}
               }
             )

    assert %Rez.AST.Inventory{id: "strongbox"} = ast
    assert %Rez.AST.Attribute{value: 10} = NodeHelper.get_attr(ast, "max_weight")

    assert [%Rez.AST.Contains{id: "tray"}, %Rez.AST.Contains{id: "floor"}] =
             NodeHelper.get_meta(ast, "nested_contains")
  end

  test "rejects @contains in an alias of an element other than @inventory" do
    input = """
    @npc bob {
      @contains pocket {
        slot_id: #ring_slot
      }
    }
    """

    assert %{status: {:fatal, _}} =
             Ergo.parse(aliased_element(), input,
               data: %{
                 id_map: %{},
                 source: dummy_source(input),
                 aliases: %{"npc" => "actor"}
               }
             )
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
