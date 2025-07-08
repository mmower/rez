defmodule Rez.Compiler.Phases.ApplySchema do
  @moduledoc """
  Compiler phase that copies the stdlib.rez to the src folder
  @todo Something odd about this...
  """
  alias Rez.AST.Node
  alias Rez.AST.NodeHelper

  alias Rez.Compiler.Compilation
  alias Rez.Compiler.Validation
  alias Rez.Compiler.SchemaBuilder.SchemaRule

  def run_phase(
        %Compilation{
          status: :ok,
          content: content,
          id_map: id_map,
          schema: schema
        } = compilation
      ) do
    File.write!("content.exs", "content = " <> inspect(content, pretty: true, limit: :infinity))
    File.write!("id_map.exs", "id_map = " <> inspect(id_map, pretty: true, limit: :infinity))

    content = apply_schema(schema, content, id_map)
    compilation = %{compilation | content: content}

    Enum.reduce(content, compilation, fn %{validation: validation} = _node, compilation ->
      Enum.reduce(validation.errors, compilation, fn error, compilation ->
        Compilation.add_error(compilation, error)
      end)
    end)
  end

  def run_phase(%Compilation{} = compilation) do
    compilation
  end

  def apply_schema(%{} = schema, content, id_map) when is_list(content) do
    Enum.map(content, &apply_schema_to_node(&1, schema_for_node(&1, schema), id_map))
  end

  def apply_schema_to_node(node, nil, _) do
    node
  end

  def apply_schema_to_node(node, rules, id_map) when is_list(rules) do
    {node, validation} =
      Enum.reduce(
        rules,
        {node, %Validation{}},
        fn %SchemaRule{} = rule, {node, validation} ->
          SchemaRule.execute(rule, node, validation, id_map)
        end
      )

    %{
      node
      | status: if(Enum.empty?(validation.errors), do: :ok, else: :error),
        validation: validation
    }
  end

  def schema_for_node(node, schema) do
    node_type_schema = Map.get(schema, Node.node_type(node), [])

    if Map.has_key?(node, :attributes) do
      case NodeHelper.get_attr(node, "$alias") do
        nil ->
          node_type_schema

        alias ->
          Map.get(schema, alias, node_type_schema)
      end
    else
      node_type_schema
    end
  end
end
