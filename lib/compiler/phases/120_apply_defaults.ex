defmodule Rez.Compiler.Phases.ApplyDefaults do
  @moduledoc """
  Implements the apply defaults phase of the Rez compiler.

  It iterates the AST nodes looking for nodes with an $alias attribute. Then
  copies attributes defined by the alias.

  Where the alias also has an alias it copies from the closest matching alias.
  """
  alias Rez.AST.NodeHelper

  alias Rez.Compiler.Compilation

  def run_phase(%Compilation{status: :ok, content: content, defaults: defaults} = compilation) do
    %{
      compilation
      | content: Enum.map(content, &apply_defaults(&1, defaults))
    }
  end

  def run_phase(compilation), do: compilation

  def apply_defaults(%{game_element: true} = node, defaults) do
    Enum.reduce(NodeHelper.get_meta(node, "alias_chain", []), node, fn elem, node ->
      merge_defaults(node, elem, defaults)
    end)
  end

  def apply_defaults(node, _compilation) do
    node
  end

  def merge_defaults(%{} = node, target, %{} = defaults) when is_binary(target) do
    case Map.get(defaults, target) do
      nil ->
        # No default, return unchanged
        node

      defaults ->
        # Reverse merge to ensure defaults don't overwrite existing attrs
        # Uses smart_merge to handle merge_set unions
        # Then consolidate_merge_sets converts any remaining merge_sets to regular sets
        %{node | attributes: defaults |> smart_merge(node.attributes) |> consolidate_merge_sets()}
    end
  end

  # Smart merge that handles merge_set by unioning with default set
  defp smart_merge(defaults, node_attrs) do
    Map.merge(defaults, node_attrs, fn _key, default_attr, node_attr ->
      merge_attribute(default_attr, node_attr)
    end)
  end

  defp merge_attribute(
         %{type: :set, value: default_set},
         %{type: :merge_set, value: merge_values} = node_attr
       ) do
    %{node_attr | type: :set, value: MapSet.union(default_set, merge_values)}
  end

  defp merge_attribute(_default_attr, node_attr), do: node_attr

  # Convert any remaining merge_sets to regular sets
  # This handles the case where a merge_set has no corresponding default to merge with
  defp consolidate_merge_sets(attrs) do
    Map.new(attrs, fn
      {k, %{type: :merge_set} = attr} -> {k, %{attr | type: :set}}
      {k, attr} -> {k, attr}
    end)
  end
end
