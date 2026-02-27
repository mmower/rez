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
  alias Rez.AST.NodeHelper

  def run_phase(%Compilation{status: :ok, content: content, progress: progress} = compilation) do
    case merge_nodes(content) do
      {:ok, merged} ->
        %{
          compilation
          | content: merged,
            progress: ["Consolidated nodes" | progress]
        }

      {:error, errors} ->
        Enum.reduce(errors, compilation, fn error, acc ->
          Compilation.add_error(acc, error)
        end)
    end
  end

  def run_phase(compilation) do
    compilation
  end

  def merge_nodes(node_list) do
    {merged_map, errors} =
      node_list
      |> Enum.with_index()
      |> Enum.reduce({%{}, []}, fn {node, index}, {acc, errors} ->
        case Map.get(node, :id) do
          nil ->
            key = make_ref()
            {Map.put(acc, key, {node, index}), errors}

          id ->
            case Map.get(acc, id) do
              nil ->
                {Map.put(acc, id, {node, index}), errors}

              {existing_node, existing_index} ->
                if existing_node.__struct__ != node.__struct__ do
                  existing_kind = NodeHelper.element_kind(existing_node)
                  new_kind = NodeHelper.element_kind(node)

                  error =
                    "ID '#{id}' is used by both @#{existing_kind} and @#{new_kind} — each element must have a unique ID"

                  {acc, [error | errors]}
                else
                  {Map.put(acc, id, {merge_node(existing_node, node), existing_index}), errors}
                end
            end
        end
      end)

    if errors == [] do
      nodes =
        merged_map
        |> Map.values()
        |> Enum.sort_by(fn {_node, index} -> index end)
        |> Enum.map(fn {node, _index} -> node end)

      {:ok, nodes}
    else
      {:error, Enum.reverse(errors)}
    end
  end

  def merge_node(%{attributes: ex_attrs} = existing_node, %{attributes: new_attrs}) do
    %{existing_node | attributes: Map.merge(ex_attrs, new_attrs)}
  end
end
