defmodule Rez.Compiler.Phases.ExpandInlineElements do
  @moduledoc """
  Implements the expand inline elements phase of the Rez compiler.

  When an author writes an inline table value as an attribute of a game element,
  this phase transparently synthesizes a separate `@object` sub-element and
  replaces the inline table with an `_id` elem_ref attribute.

  For example:

      @object a {
        stats: {
          str: 5
          end: 6
        }
      }

  Is internally compiled as:

      @object a_stats { str: 5  end: 6 }
      @object a { stats_id: #a_stats }

  A homogeneous list of inline tables is also supported:

      @object a {
        stats: [{name: "str" val: 14} {name: "con" val: 12}]
      }

  Is internally compiled as:

      @object a_stats_0 { name: "str"  val: 14 }
      @object a_stats_1 { name: "con"  val: 12 }
      @object a { stats: [#a_stats_0 #a_stats_1] }

  Mixed lists (tables alongside other value types) are a compile error.
  """

  alias Rez.Compiler.Compilation
  alias Rez.AST.Attribute
  alias Rez.AST.Object

  def run_phase(%Compilation{status: :ok, content: content, progress: progress} = compilation) do
    case expand_all(content) do
      {:ok, expanded_content} ->
        %{
          compilation
          | content: expanded_content,
            progress: ["Expanded inline elements" | progress]
        }

      {:error, error} ->
        Compilation.add_error(compilation, error)
    end
  end

  def run_phase(compilation), do: compilation

  defp expand_all(content) do
    {expanded, errors} =
      Enum.reduce(content, {[], []}, fn node, {nodes_acc, errors_acc} ->
        if Map.get(node, :game_element) == true do
          case expand_game_element(node) do
            {:ok, {updated_node, new_nodes}} ->
              {nodes_acc ++ [updated_node] ++ new_nodes, errors_acc}

            {:error, error} ->
              {nodes_acc ++ [node], [error | errors_acc]}
          end
        else
          {nodes_acc ++ [node], errors_acc}
        end
      end)

    if errors == [] do
      {:ok, expanded}
    else
      {:error, Enum.join(Enum.reverse(errors), "; ")}
    end
  end

  def expand_game_element(%{game_element: true} = node) do
    result =
      Enum.reduce_while(node.attributes, {:ok, {node, []}}, fn {name, attr},
                                                                {:ok, {node_acc, new_nodes}} ->
        case attr do
          %Attribute{type: :table, value: table_map} ->
            ref_name = name <> "_id"

            if Map.has_key?(node_acc.attributes, ref_name) do
              {:halt,
               {:error,
                "Attribute '#{ref_name}' already exists on element '#{node_acc.id}' — conflict with inline table expansion of '#{name}'"}}
            else
              case expand_table(node_acc.id, name, table_map, node_acc.position) do
                {:ok, {sub_id, sub_obj, child_nodes}} ->
                  ref_attr = Attribute.elem_ref(ref_name, sub_id)

                  updated_attrs =
                    node_acc.attributes
                    |> Map.delete(name)
                    |> Map.put(ref_name, ref_attr)

                  {:cont, {:ok, {%{node_acc | attributes: updated_attrs}, child_nodes ++ new_nodes ++ [sub_obj]}}}

                {:error, _} = err ->
                  {:halt, err}
              end
            end

          %Attribute{type: :list, value: values} = list_attr ->
            case classify_list(values) do
              :no_tables ->
                {:cont, {:ok, {node_acc, new_nodes}}}

              :all_tables ->
                case expand_table_list(node_acc.id, name, values, node_acc.position) do
                  {:ok, {new_refs, child_nodes}} ->
                    updated_attr = %Attribute{list_attr | value: new_refs}
                    updated_attrs = Map.put(node_acc.attributes, name, updated_attr)
                    {:cont, {:ok, {%{node_acc | attributes: updated_attrs}, child_nodes ++ new_nodes}}}

                  {:error, _} = err ->
                    {:halt, err}
                end

              :mixed ->
                {:halt,
                 {:error,
                  "List attribute '#{name}' on '#{node_acc.id}' mixes table items with non-table items — use a homogeneous list of tables or no tables"}}
            end

          _ ->
            {:cont, {:ok, {node_acc, new_nodes}}}
        end
      end)

    result
  end

  defp expand_table(parent_id, attr_name, table_map, position) do
    sub_id = "#{parent_id}_#{attr_name}"

    sub_node = %Object{
      id: sub_id,
      attributes: table_map,
      game_element: true,
      position: position
    }

    case expand_game_element(sub_node) do
      {:ok, {expanded_sub, child_nodes}} ->
        {:ok, {sub_id, expanded_sub, child_nodes}}

      {:error, _} = err ->
        err
    end
  end

  defp classify_list(values) do
    has_tables = Enum.any?(values, &match?({:table, _}, &1))
    has_non_tables = Enum.any?(values, &(not match?({:table, _}, &1)))

    cond do
      has_tables and has_non_tables -> :mixed
      has_tables -> :all_tables
      true -> :no_tables
    end
  end

  defp expand_table_list(parent_id, attr_name, values, position) do
    values
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, {[], []}}, fn {{:table, table_map}, idx}, {:ok, {refs, nodes}} ->
      sub_id = "#{parent_id}_#{attr_name}_#{idx}"
      sub_node = %Object{id: sub_id, attributes: table_map, game_element: true, position: position}

      case expand_game_element(sub_node) do
        {:ok, {expanded_sub, child_nodes}} ->
          {:cont, {:ok, {refs ++ [{:elem_ref, sub_id}], nodes ++ [expanded_sub] ++ child_nodes}}}

        {:error, _} = err ->
          {:halt, err}
      end
    end)
  end
end
