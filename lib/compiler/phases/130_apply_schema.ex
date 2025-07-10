defmodule Rez.Compiler.Phases.ApplySchema do
  @moduledoc """
  Compiler phase that applies the schema rules to all game elements for which
  a schema has been defined.
  """
  alias Rez.Compiler.AliasChain
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

  def apply_schema(%{} = schema, content, id_map) when is_list(content) do
    Enum.map(content, &apply_schema_to_node(&1, schema_for_node(&1, schema), id_map))
  end

  def apply_schema_to_node(node, [], _) do
    node
  end

  def apply_schema_to_node(node, schema_list, id_map) when is_list(schema_list) do
    {node, validation} =
      Enum.reduce(
        List.flatten(schema_list),
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
    node
    |> NodeHelper.get_meta("alias_chain", [])
    |> Enum.map(&Map.get(schema, &1))
  end
end
