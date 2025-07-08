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
            SchemaBuilder.build("name", [{:kind, [:string]}, {:required, true}]),
            SchemaBuilder.build("initial_scene_id", [
              {:kind, [:elem_ref]},
              {:ref_elem, [:scene]},
              {:required, true}
            ])
          ]
        ],
        {nil, 0, 0}
      ),
      item_2,
      SchemaParser.make_schema(
        [
          "item",
          [SchemaBuilder.build("inv_type", [{:kind, [:keyword]}, {:default, {:keyword, "item"}}])]
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
               description: "Validate that initial_scene_id is present"
             },
             %SchemaBuilder.SchemaRule{
               description: "Validate that name is present"
             },
             %SchemaBuilder.SchemaRule{
               description: "Validate initial_scene_id is of kind elem_ref"
             },
             %SchemaBuilder.SchemaRule{
               description: "Validate name is of kind string"
             },
             %SchemaBuilder.SchemaRule{
               description: "Validate initial_scene_id is a ref to an element [:scene]"
             }
           ] = game_schema

    assert [
             %SchemaBuilder.SchemaRule{
               description: "Set default inv_type to :item"
             },
             %SchemaBuilder.SchemaRule{
               description: "Validate inv_type is of kind keyword"
             }
           ] = item_schema
  end
end
