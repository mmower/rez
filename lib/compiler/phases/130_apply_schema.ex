defmodule Rez.Compiler.Phases.ApplySchema do
  @moduledoc """
  Compiler phase that applies the schema rules to all game elements for which
  a schema has been defined.
  """
  alias Rez.AST.{Contains, Inventory, NodeHelper}

  alias Rez.Compiler.Compilation
  alias Rez.Compiler.Validation
  alias Rez.Compiler.SchemaBuilder.SchemaRule
  alias Rez.Compiler.SchemaBuilder.PatternRule

  def run_phase(
        %Compilation{
          status: :ok,
          content: content,
          schema: schema
        } = compilation
      ) do
    content = apply_schema(schema, content, compilation)
    compilation = %{compilation | content: content}

    content
    |> Enum.reduce(
      compilation,
      fn
        %{validation: %Validation{} = validation} = _node, compilation ->
          Enum.reduce(validation.errors, compilation, fn error, compilation ->
            Compilation.add_error(compilation, error)
          end)

        _node, compilation ->
          compilation
      end
    )
  end

  def run_phase(%Compilation{} = compilation) do
    compilation
  end

  def apply_schema(%{} = schema, content, lookup) when is_list(content) do
    Enum.map(content, fn node ->
      node
      |> apply_schema_to_node(schema_for_node(node, schema), lookup)
      |> apply_schema_to_positions(schema, lookup)
    end)
  end

  # The `@contains` blocks nested in an `@inventory` are not part of the
  # content so validate them here, against `@schema contains`, and report any
  # errors against their inventory.
  defp apply_schema_to_positions(%Inventory{id: inv_id} = inventory, schema, lookup) do
    {positions, errors} =
      inventory
      |> NodeHelper.get_meta("nested_contains", [])
      |> Enum.map_reduce([], fn %Contains{id: pos_id} = pos, errors ->
        pos = apply_schema_to_node(pos, schema_for_node(pos, schema), lookup)
        {pos, errors ++ position_errors(pos, inv_id, pos_id)}
      end)

    inventory = NodeHelper.set_meta(inventory, "nested_contains", positions)

    case errors do
      [] ->
        inventory

      errors ->
        validation = inventory.validation || %Validation{}

        %{
          inventory
          | status: :error,
            validation: %{validation | errors: validation.errors ++ errors}
        }
    end
  end

  defp apply_schema_to_positions(node, _schema, _lookup), do: node

  defp position_errors(%Contains{validation: %Validation{errors: errors}}, inv_id, pos_id) do
    Enum.map(errors, fn {_type, _id, error} ->
      {"inventory", inv_id, "@contains #{pos_id}: #{error}"}
    end)
  end

  defp position_errors(_pos, _inv_id, _pos_id), do: []

  def apply_schema_to_node(node, [], _) do
    node
  end

  def apply_schema_to_node(node, schema_list, lookup) when is_list(schema_list) do
    {node, validation} =
      Enum.reduce(
        List.flatten(schema_list),
        {node, %Validation{}},
        fn
          %SchemaRule{} = rule, {node, validation} ->
            SchemaRule.execute(rule, node, validation, lookup)

          %PatternRule{} = pattern_rule, {node, validation} ->
            apply_pattern_rule_to_node(pattern_rule, node, validation, lookup)
        end
      )

    %{
      node
      | status: if(Enum.empty?(validation.errors), do: :ok, else: :error),
        validation: validation
    }
  end

  defp apply_pattern_rule_to_node(pattern_rule, node, validation, lookup) do
    node
    |> NodeHelper.attr_names()
    |> Enum.filter(&PatternRule.matches?(pattern_rule, &1))
    |> Enum.reduce({node, validation}, fn attr_name, {node_acc, validation_acc} ->
      PatternRule.execute(pattern_rule, attr_name, node_acc, validation_acc, lookup)
    end)
  end

  def schema_for_node(node, schema) do
    node
    |> NodeHelper.get_meta("alias_chain", [])
    |> Enum.map(&Map.get(schema, &1))
    |> Enum.reject(&is_nil(&1))
  end
end
