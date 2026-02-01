defmodule Rez.Compiler.ExecSchemaTest do
  use ExUnit.Case

  alias Rez.AST.Attribute
  alias Rez.AST.NodeHelper, as: NH

  alias Rez.Compiler.Compilation
  alias Rez.Compiler.SchemaBuilder
  alias Rez.Compiler.Phases.ApplySchema
  alias Rez.Compiler.Phases.BuildSchema

  alias Rez.Parser.SchemaParser

  test "Applies schema" do
    schema = create_schema()

    item = %Rez.AST.Item{
      id: "item_1",
      attributes: %{"inv_type" => Attribute.keyword("inv_type", "item")},
      metadata: %{"alias_chain" => ["item"]}
    }

    [validated_item] = ApplySchema.apply_schema(schema, [item], %{"item_id" => item})
    assert "item" = NH.get_attr_value(validated_item, "inv_type")
    assert [] = validated_item.validation.errors

    item =
      %Rez.AST.Item{id: "item_2", metadata: %{"alias_chain" => ["item"]}}
      |> NH.set_string_attr("inv_type", "item")

    [validated_item] = ApplySchema.apply_schema(schema, [item], %{"item_id" => item})
    %{validation: validation} = validated_item

    assert [{"item", "item_2", "inv_type must be of kind keyword but was string"}] =
             validation.errors
  end

  test "Validates @game" do
    game =
      %Rez.AST.Game{}
      |> NH.set_string_attr("name", "Test")
      |> NH.set_elem_ref_attr("initial_scene_id", "s_intro")

    scene =
      %Rez.AST.Scene{id: "s_intro"}

    compilation =
      %Compilation{status: :ok, content: [game, scene]}
      |> BuildSchema.run_phase()
      |> ApplySchema.run_phase()

    assert [] = compilation.errors
  end

  test "Applies pattern rules for dynamic attributes" do
    schema = create_pattern_schema()

    # Test item with valid pattern matches
    item = %Rez.AST.Item{
      id: "test_item",
      attributes: %{
        "scene_id" => Attribute.elem_ref("scene_id", "s_intro"),
        "item_count" => Attribute.number("item_count", 5),
        "gold_count" => Attribute.number("gold_count", 10)
      },
      metadata: %{"alias_chain" => ["item"]}
    }

    scene = %Rez.AST.Scene{id: "s_intro"}

    [validated_item] = ApplySchema.apply_schema(schema, [item], %{id_map: %{"s_intro" => scene}})
    assert [] = validated_item.validation.errors

    # Test item with invalid pattern matches
    invalid_item = %Rez.AST.Item{
      id: "invalid_item",
      attributes: %{
        "scene_id" => Attribute.string("scene_id", "not_a_ref"),
        "item_count" => Attribute.number("item_count", -1)
      },
      metadata: %{"alias_chain" => ["item"]}
    }

    [validated_invalid] = ApplySchema.apply_schema(schema, [invalid_item], %{id_map: %{}})
    errors = validated_invalid.validation.errors

    # Should have errors for wrong type and negative value
    # Note: scene_id gets 2 errors (wrong type + not a ref) because 2 pattern rules match it
    assert length(errors) == 3

    assert Enum.any?(errors, fn {_, _, msg} ->
             String.contains?(msg, "scene_id") and String.contains?(msg, "ref")
           end)

    assert Enum.any?(errors, fn {_, _, msg} ->
             String.contains?(msg, "item_count") and String.contains?(msg, ">= 0")
           end)
  end

  test "Pattern rules work alongside exact attribute rules" do
    schema = create_mixed_schema()

    item = %Rez.AST.Item{
      id: "mixed_item",
      attributes: %{
        "name" => Attribute.string("name", "Test Item"),
        "scene_id" => Attribute.elem_ref("scene_id", "s_intro"),
        "unlock_flag" => Attribute.keyword("unlock_flag", "flag")
      },
      metadata: %{"alias_chain" => ["item"]}
    }

    scene = %Rez.AST.Scene{id: "s_intro"}

    [validated_item] = ApplySchema.apply_schema(schema, [item], %{id_map: %{"s_intro" => scene}})
    assert [] = validated_item.validation.errors
  end

  test "Pattern rule validates coll_kind correctly" do
    schema = create_coll_kind_pattern_schema()

    # Test item with valid collection contents
    item = %Rez.AST.Item{
      id: "test_item",
      attributes: %{
        "test_contents" =>
          Attribute.list("test_contents", [
            {:elem_ref, "item_1"},
            {:elem_ref, "item_2"}
          ]),
        "other_contents" =>
          Attribute.list("other_contents", [
            {:elem_ref, "item_3"}
          ])
      },
      metadata: %{"alias_chain" => ["item"]}
    }

    item1 = %Rez.AST.Item{id: "item_1"}
    item2 = %Rez.AST.Item{id: "item_2"}
    item3 = %Rez.AST.Item{id: "item_3"}

    [validated_item] =
      ApplySchema.apply_schema(schema, [item], %{
        id_map: %{"item_1" => item1, "item_2" => item2, "item_3" => item3},
        aliases: %{}
      })

    assert [] = validated_item.validation.errors

    # Test item with invalid collection contents (wrong type)
    invalid_item = %Rez.AST.Item{
      id: "invalid_item",
      attributes: %{
        "bad_contents" =>
          Attribute.list("bad_contents", [
            {:string, "not_an_elem_ref"}
          ])
      },
      metadata: %{"alias_chain" => ["item"]}
    }

    [validated_invalid] = ApplySchema.apply_schema(schema, [invalid_item], %{id_map: %{}})
    errors = validated_invalid.validation.errors

    # Should have error for wrong collection content type
    assert length(errors) >= 1

    assert Enum.any?(errors, fn {_, _, msg} ->
             String.contains?(msg, "bad_contents") and String.contains?(msg, "collection")
           end)
  end

  def create_pattern_schema() do
    {:ok, id_pattern_rules} =
      SchemaBuilder.build_pattern(".*_id", [{:kind, [:elem_ref]}, {:ref_elem, ["scene"]}])

    {:ok, count_pattern_rules} =
      SchemaBuilder.build_pattern(".*_count", [{:kind, [:number]}, {:min_value, 0}])

    BuildSchema.build_schema([
      SchemaParser.make_schema(
        [
          "item",
          id_pattern_rules ++ count_pattern_rules
        ],
        {nil, 0, 0}
      )
    ])
  end

  def create_mixed_schema() do
    {:ok, id_pattern_rules} =
      SchemaBuilder.build_pattern(".*_id", [{:kind, [:elem_ref]}, {:ref_elem, ["scene"]}])

    {:ok, unlock_pattern_rules} = SchemaBuilder.build_pattern("unlock_.*", [{:kind, [:keyword]}])

    BuildSchema.build_schema([
      SchemaParser.make_schema(
        [
          "item",
          elem(SchemaBuilder.build("name", [{:kind, [:string]}, {:required, true}]), 1) ++
            id_pattern_rules ++
            unlock_pattern_rules
        ],
        {nil, 0, 0}
      )
    ])
  end

  def create_coll_kind_pattern_schema() do
    {:ok, contents_pattern_rules} =
      SchemaBuilder.build_pattern(".*_contents", [{:kind, [:list]}, {:coll_kind, [:elem_ref]}])

    BuildSchema.build_schema([
      SchemaParser.make_schema(
        [
          "item",
          contents_pattern_rules
        ],
        {nil, 0, 0}
      )
    ])
  end

  def create_schema() do
    BuildSchema.build_schema([
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
      SchemaParser.make_schema(
        [
          "item",
          [elem(SchemaBuilder.build("inv_type", [{:kind, [:keyword]}]), 1)]
        ],
        {nil, 0, 0}
      )
    ])
  end

  test "min_length rule returns proper tuple format" do
    # This test ensures the min_length rule fix works correctly
    item = %Rez.AST.Item{
      id: "test_item",
      attributes: %{},
      metadata: %{"alias_chain" => ["item"]}
    }

    {:ok, rules} =
      SchemaBuilder.build("slots", [{:kind, [:set]}, {:required, true}, {:min_length, 1}])

    # This should not crash with a FunctionClauseError
    result = ApplySchema.apply_schema_to_node(item, rules, %{})

    # Should have validation errors for missing required field
    assert result.status == :error
    assert length(result.validation.errors) > 0
  end

  test "type_exists rule validates derived types" do
    alias Rez.AST.TypeHierarchy

    # Create a type hierarchy with a derived type
    type_hierarchy =
      TypeHierarchy.new()
      |> TypeHierarchy.add("weapon", "item")

    # Create a schema with type_exists validation
    {:ok, rules} =
      SchemaBuilder.build("accepts", [{:kind, [:keyword]}, {:required, true}, :type_exists])

    # Test with a valid derived type
    slot_valid = %Rez.AST.Slot{
      id: "weapon_slot",
      attributes: %{"accepts" => Attribute.keyword("accepts", "weapon")},
      metadata: %{"alias_chain" => ["slot"]}
    }

    result =
      ApplySchema.apply_schema_to_node(slot_valid, rules, %{type_hierarchy: type_hierarchy})

    assert [] = result.validation.errors

    # Test with a non-existent derived type
    slot_invalid = %Rez.AST.Slot{
      id: "invalid_slot",
      attributes: %{"accepts" => Attribute.keyword("accepts", "weaponx")},
      metadata: %{"alias_chain" => ["slot"]}
    }

    result =
      ApplySchema.apply_schema_to_node(slot_invalid, rules, %{type_hierarchy: type_hierarchy})

    assert length(result.validation.errors) == 1

    assert [{"slot", "invalid_slot", error_msg}] = result.validation.errors

    assert String.contains?(error_msg, "weaponx") and
             String.contains?(error_msg, "not been derived")
  end

  test "type_exists rule validates parent types that don't themselves derive" do
    alias Rez.AST.TypeHierarchy

    # Create a type hierarchy where "weapon" derives from "item"
    # Here "item" is a parent type that doesn't derive from anything
    type_hierarchy =
      TypeHierarchy.new()
      |> TypeHierarchy.add("weapon", "item")

    # Create a schema with type_exists validation
    {:ok, rules} =
      SchemaBuilder.build("accepts", [{:kind, [:keyword]}, {:required, true}, :type_exists])

    # Test with the parent type "item" - should be valid since it exists in the hierarchy
    slot_with_parent = %Rez.AST.Slot{
      id: "item_slot",
      attributes: %{"accepts" => Attribute.keyword("accepts", "item")},
      metadata: %{"alias_chain" => ["slot"]}
    }

    result =
      ApplySchema.apply_schema_to_node(slot_with_parent, rules, %{type_hierarchy: type_hierarchy})

    assert [] = result.validation.errors
  end

  test "no_key_overlap rule detects conflicting names between bindings and blocks" do
    # Create a schema with no_key_overlap validation
    {:ok, bindings_rules} =
      SchemaBuilder.build("bindings", [
        {:kind, [:list]},
        {:coll_kind, [:list_binding]},
        {:no_key_overlap, "blocks"}
      ])

    {:ok, blocks_rules} =
      SchemaBuilder.build("blocks", [{:kind, [:list]}, {:coll_kind, [:list_binding]}])

    rules = List.flatten([bindings_rules, blocks_rules])

    # Test with conflicting names - "foo" appears in both bindings and blocks
    card_conflict = %Rez.AST.Card{
      id: "test_card",
      attributes: %{
        "bindings" =>
          Attribute.list("bindings", [
            {:list_binding, {"foo", {:elem_ref, "some_object"}}}
          ]),
        "blocks" =>
          Attribute.list("blocks", [
            {:list_binding, {"foo", {:elem_ref, "some_card"}}}
          ])
      },
      metadata: %{"alias_chain" => ["card"]}
    }

    result = ApplySchema.apply_schema_to_node(card_conflict, rules, %{})

    assert length(result.validation.errors) == 1
    assert [{"card", "test_card", error_msg}] = result.validation.errors
    assert String.contains?(error_msg, "bindings")
    assert String.contains?(error_msg, "blocks")
    assert String.contains?(error_msg, "foo")
  end

  test "no_key_overlap rule passes when no conflicts exist" do
    {:ok, bindings_rules} =
      SchemaBuilder.build("bindings", [
        {:kind, [:list]},
        {:coll_kind, [:list_binding]},
        {:no_key_overlap, "blocks"}
      ])

    {:ok, blocks_rules} =
      SchemaBuilder.build("blocks", [{:kind, [:list]}, {:coll_kind, [:list_binding]}])

    rules = List.flatten([bindings_rules, blocks_rules])

    # Test with no conflicts - different names in bindings and blocks
    card_no_conflict = %Rez.AST.Card{
      id: "test_card",
      attributes: %{
        "bindings" =>
          Attribute.list("bindings", [
            {:list_binding, {"obj", {:elem_ref, "some_object"}}}
          ]),
        "blocks" =>
          Attribute.list("blocks", [
            {:list_binding, {"card", {:elem_ref, "some_card"}}}
          ])
      },
      metadata: %{"alias_chain" => ["card"]}
    }

    result = ApplySchema.apply_schema_to_node(card_no_conflict, rules, %{})
    assert [] = result.validation.errors
  end

  test "no_key_overlap rule handles missing attributes" do
    {:ok, bindings_rules} =
      SchemaBuilder.build("bindings", [
        {:kind, [:list]},
        {:coll_kind, [:list_binding]},
        {:no_key_overlap, "blocks"}
      ])

    rules = List.flatten([bindings_rules])

    # Test with only bindings, no blocks
    card_bindings_only = %Rez.AST.Card{
      id: "test_card",
      attributes: %{
        "bindings" =>
          Attribute.list("bindings", [
            {:list_binding, {"foo", {:elem_ref, "some_object"}}}
          ])
      },
      metadata: %{"alias_chain" => ["card"]}
    }

    result = ApplySchema.apply_schema_to_node(card_bindings_only, rules, %{})
    assert [] = result.validation.errors

    # Test with neither bindings nor blocks
    card_empty = %Rez.AST.Card{
      id: "empty_card",
      attributes: %{},
      metadata: %{"alias_chain" => ["card"]}
    }

    result = ApplySchema.apply_schema_to_node(card_empty, rules, %{})
    assert [] = result.validation.errors
  end
end
