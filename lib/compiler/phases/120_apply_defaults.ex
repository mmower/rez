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
        %{node | attributes: Map.merge(defaults, node.attributes)}
    end
  end
end
