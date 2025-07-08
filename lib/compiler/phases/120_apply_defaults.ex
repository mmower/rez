defmodule Rez.Compiler.Phases.ApplyDefaults do
  @moduledoc """
  Implements the apply defaults phase of the Rez compiler.

  It iterates the AST nodes looking for nodes with an $alias attribute. Then
  copies attributes defined by the alias.

  Where the alias also has an alias it copies from the closest matching alias.
  """
  alias Rez.Compiler.Compilation

  alias Rez.AST.Node
  alias Rez.AST.NodeHelper

  def run_phase(%Compilation{status: :ok, content: content} = compilation) do
    %{
      compilation
      | content: Enum.map(content, &apply_defaults(&1, compilation))
    }
  end

  def run_phase(compilation), do: compilation

  def apply_defaults(%{game_element: true} = node, compilation) do
    Enum.reduce(alias_chain(node, compilation), node, fn elem, node ->
      merge_defaults(node, elem, compilation.defaults)
    end)
  end

  def apply_defaults(node, _compilation) do
    node
  end

  def alias_chain(node, compilation) do
    case NodeHelper.get_attr_value(node, "$alias") do
      nil ->
        [Node.node_type(node)]

      alias_name ->
        build_alias_chain(compilation.aliases, alias_name) ++ [Node.node_type(node)]
    end
  end

  def build_alias_chain(aliases, alias_name) do
    case Map.get(aliases, alias_name) do
      nil ->
        []

      alias_node ->
        [alias_name | build_alias_chain(aliases, alias_node.target)]
    end
  end

  def merge_defaults(node, target, defaults) do
    case Map.get(defaults, target) do
      nil ->
        # No default, return unchanged
        node

      defaults ->
        # Reverse merge to ensure defaults don't overwrite existing attrs
        %{node | attributes: Map.merge(defaults, node.attributes)}
    end
  end
end
