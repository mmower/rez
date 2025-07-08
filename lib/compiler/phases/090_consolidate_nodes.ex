defmodule Rez.Compiler.Phases.ConsolidateNodes do
  @moduledoc """
  Implements the consolidate nodes phase of the Rez compiler.

  The parser returns a list of AST nodes, some of which may represent the same
  id, for example:

  @object o_1 {
    a: true
  }

  @object o_1 {
    b: false
  }

  Returns two Rez.AST.Object nodes with the same id. These get consolidated
  into one object with the attributes of each. If the same attribute is defined
  more than once, the last usage will overwrite the earlier ones.
  """
  alias Rez.Compiler.Compilation

  def run_phase(%Compilation{status: :ok, content: content, progress: progress} = compilation) do
    content = merge_nodes(content)

    %{
      compilation
      | content: merge_nodes(content),
        progress: ["Consolidated nodes" | progress]
    }
  end

  def run_phase(compilation) do
    compilation
  end

  def merge_nodes(node_list) do
    node_list
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {node, index}, acc ->
      case Map.get(node, :id) do
        nil ->
          key = make_ref()
          Map.put(acc, key, {node, index})

        id ->
          Map.update(acc, id, {node, index}, fn {existing_node, existing_index} ->
            {merge_node(existing_node, node), existing_index}
          end)
      end
    end)
    |> Map.values()
    |> Enum.sort_by(fn {_node, index} -> index end)
    |> Enum.map(fn {node, _index} -> node end)
  end

  def merge_node(%{attributes: ex_attrs} = existing_node, %{attributes: new_attrs}) do
    %{existing_node | attributes: Map.merge(ex_attrs, new_attrs)}
  end
end
