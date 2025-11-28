defmodule Rez.Compiler.Phases.BuildSchema do
  @moduledoc """
  Implements the build schema phase of the Rez compiler.

  It removes Schema AST nodes from the AST node list using them to build a
  schema map which is then added to the compilation.
  """
  alias Rez.Compiler.Compilation
  alias Rez.AST.NodeHelper
  alias Rez.AST.TypeHierarchy

  def run_phase(%Compilation{status: :ok, content: content, progress: progress} = compilation) do
    # We don't want Schema, Alias, Default, or Derive nodes to be part of the
    # content list after this step hence why we split rather than just filtering
    {schema_nodes, content} = NodeHelper.extract_nodes(content, Rez.AST.Schema)
    {defaults_nodes, content} = NodeHelper.extract_nodes(content, Rez.AST.Defaults)
    {alias_nodes, content} = NodeHelper.extract_nodes(content, Rez.AST.Alias)
    {derive_nodes, content} = NodeHelper.extract_nodes(content, Rez.AST.Derive)
    {pragma_nodes, content} = NodeHelper.extract_nodes(content, Rez.AST.Pragma)

    %{
      compilation
      | content: content,
        defaults: build_defaults(defaults_nodes),
        aliases: build_aliases(alias_nodes),
        schema: build_schema(schema_nodes),
        type_hierarchy: build_type_hierarchy(derive_nodes),
        pragmas: pragma_nodes,
        progress: ["Built schema" | progress]
    }
  end

  def run_phase(compilation) do
    compilation
  end

  def build_schema(schema_nodes) do
    schema_nodes
    |> Enum.reduce(%{}, fn %{element: element, rules: rules}, schema ->
      Map.put(schema, element, rules)
    end)
  end

  def build_defaults(default_nodes) do
    Enum.reduce(default_nodes, %{}, fn node, defaults_map ->
      Map.put(defaults_map, node.elem, node.attributes)
    end)
  end

  def build_aliases(alias_nodes) do
    Enum.reduce(alias_nodes, %{}, fn %{name: name} = alias, alias_map ->
      Map.put(alias_map, name, alias)
    end)
  end

  def build_type_hierarchy(content) do
    Enum.reduce(
      content,
      TypeHierarchy.new(),
      fn
        %Rez.AST.Derive{tag: tag, parent: parent_tag}, hierarchy ->
          TypeHierarchy.add(hierarchy, tag, parent_tag)
      end
    )
  end
end
