defmodule Rez.Compiler.ExecSchemaTest do
  use ExUnit.Case

  alias Rez.AST.NodeHelper, as: NH

  alias Rez.Compiler.Validation
  alias Rez.Compiler.Compilation
  alias Rez.Compiler.SchemaBuilder
  alias Rez.Compiler.Phases.ApplySchema
  alias Rez.Compiler.Phases.BuildSchema

  alias Rez.Parser.SchemaParser

  test "Applies schema" do
    schema = create_schema()

    item = %Rez.AST.Item{id: "item_1"}
    [validated_item] = ApplySchema.apply_schema(schema, [item])
    assert "item" = NH.get_attr_value(validated_item, "inv_type")
    assert [] = validated_item.validation.errors

    item = %Rez.AST.Item{id: "item_2"} |> NH.set_string_attr("inv_type", "item")
    [validated_item] = ApplySchema.apply_schema(schema, [item])
    %{validation: validation} = validated_item

    assert [{"item", "item_2", "item#item_2: inv_type must be of kind keyword but was string"}] =
             validation.errors
  end

  test "Detects @game" do
    post_compilation =
      ApplySchema.run_phase(%Compilation{schema: create_schema(), content: [%Rez.AST.Game{}]})

    assert [] = post_compilation.errors

    post_compilation =
      ApplySchema.run_phase(%Compilation{
        schema: create_schema(),
        content: [%Rez.AST.Item{id: "item_1"}]
      })

    assert ["Unable to find a @game element"] = post_compilation.errors
  end

  def create_schema() do
    BuildSchema.build_schema([
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
      SchemaParser.make_schema(
        [
          "item",
          [SchemaBuilder.build("inv_type", [{:kind, [:keyword]}, {:default, {:keyword, "item"}}])]
        ],
        {nil, 0, 0}
      )
    ])
  end
end
