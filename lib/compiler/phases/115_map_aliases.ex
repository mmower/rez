defmodule Rez.Compiler.Phases.MapAliases do
  alias Rez.AST.Attribute
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
    chain = AliasChain.alias_chain(node, compilation)
    node
    |> NodeHelper.set_meta("alias_chain", chain)
    |> NodeHelper.set_attr(Attribute.list("$kinds", Enum.map(chain, &{:string, &1})))
  end

  def map_node_aliases(node, _compilation), do: node
end
