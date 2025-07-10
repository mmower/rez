defmodule Rez.Compiler.Phases.MapAliases do
  alias Rez.AST.NodeHelper

  alias Rez.Compiler.AliasChain
  alias Rez.Compiler.Compilation

  def run_phase(%Compilation{status: :ok, content: content} = compilation) do
    %{compilation | content: map_aliases(content, compilation)}
  end

  def run_phase(compilation), do: compilation

  def map_aliases(content, compilation) do
    Enum.map(content, &map_node_aliases(&1, compilation))
  end

  def map_node_aliases(%{game_element: true} = node, compilation) do
    NodeHelper.set_meta(node, "alias_chain", AliasChain.alias_chain(node, compilation))
  end

  def map_node_aliases(node, _compilation), do: node
end
