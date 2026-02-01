defmodule Rez.Compiler.BuildSchemaTest do
  use ExUnit.Case

  alias Rez.Compiler.SchemaBuilder
  alias Rez.Compiler.Compilation
  alias Rez.Compiler.Phases.BuildSchema
  alias Rez.Parser.SchemaParser

  test "builds schema" do
    item_1 = %Rez.AST.Item{id: "item_1"}
    item_2 = %Rez.AST.Item{id: "item_2"}
    item_3 = %Rez.AST.Item{id: "item_3"}
    game = %Rez.AST.Game{id: "game"}

    content = [
      game,
      item_1,
      SchemaParser.make_schema(
        [
          "game",
          [
            elem(SchemaBuilder.build("name", [{:kind, [:string]}, {:required, true}]), 1),
            elem(
              SchemaBuilder.build("initial_scene_id", [
                {:kind, [:elem_ref]},
                {:ref_elem, [:scene]},
                {:required, true}
              ]),
              1
            )
          ]
        ],
        {nil, 0, 0}
      ),
      item_2,
      SchemaParser.make_schema(
        [
          "item",
          [elem(SchemaBuilder.build("inv_type", [{:kind, [:keyword]}]), 1)]
        ],
        {nil, 0, 0}
      ),
      item_3
    ]

    compilation = BuildSchema.run_phase(%Compilation{content: content})

    assert [^game, ^item_1, ^item_2, ^item_3] = compilation.content

    assert %{"game" => game_schema, "item" => item_schema} = compilation.schema

    assert [
             %SchemaBuilder.SchemaRule{
               description: "Validate that initial_scene_id is present",
               priority: 2
             },
             %SchemaBuilder.SchemaRule{
               description: "Validate that name is present",
               priority: 2
             },
             %SchemaBuilder.SchemaRule{
               description: "Validate initial_scene_id is of kind elem_ref",
               priority: 3
             },
             %SchemaBuilder.SchemaRule{
               description: "Validate name is of kind string",
               priority: 3
             },
             %SchemaBuilder.SchemaRule{
               description: "Validate initial_scene_id is a ref to an element of type [:scene]",
               priority: 4
             }
           ] = game_schema

    assert [
             %SchemaBuilder.SchemaRule{
               description: "Validate inv_type is of kind keyword",
               priority: 3
             }
           ] = item_schema
  end

  test "builds no_key_overlap rule" do
    {:ok, rules} =
      SchemaBuilder.build("bindings", [
        {:kind, [:list]},
        {:coll_kind, [:list_binding]},
        {:no_key_overlap, "blocks"}
      ])

    # Should have 3 rules: kind, coll_kind, and no_key_overlap
    assert length(rules) == 3

    # Find the no_key_overlap rule
    overlap_rule =
      Enum.find(rules, fn rule ->
        String.contains?(rule.description, "no overlapping keys")
      end)

    assert overlap_rule != nil
    assert overlap_rule.priority == 6
    assert String.contains?(overlap_rule.description, "bindings")
    assert String.contains?(overlap_rule.description, "blocks")
  end
end
