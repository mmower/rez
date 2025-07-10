defmodule Rez.Compiler.AliasChain do
  alias Rez.Compiler.Compilation

  alias Rez.AST.Node
  alias Rez.AST.NodeHelper

  def alias_chain(node, %Compilation{aliases: aliases}) do
    case NodeHelper.get_attr_value(node, "$alias") do
      nil ->
        [Node.node_type(node)]

      alias_name ->
        build_alias_chain(aliases, alias_name) ++ [Node.node_type(node)]
    end
  end

  def build_alias_chain(%{} = aliases, alias_name) when is_binary(alias_name) do
    case Map.get(aliases, alias_name) do
      nil ->
        []

      alias_node ->
        [alias_name | build_alias_chain(aliases, alias_node.target)]
    end
  end
end
