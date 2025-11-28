defmodule Rez.Compiler.Phases.InitializationOrder do
  @moduledoc """
  This compiler phase contructs an initialization order for game objects that
  satisfies known dependencies and inserts the ordered ids into the $init_order
  attribute of the @game element.
  """
  alias Rez.AST.Node
  alias Rez.AST.NodeHelper
  alias Rez.Compiler.Compilation

  def run_phase(%Compilation{status: :ok, content: content} = compilation) do
    case create_init_order(content) do
      {:ok, init_order} ->
        %{
          compilation
          | content:
              Enum.map(
                content,
                fn
                  %Rez.AST.Game{} = game ->
                    NodeHelper.set_list_attr(
                      game,
                      "$init_order",
                      Enum.map(init_order, &{:string, &1})
                    )

                  node ->
                    node
                end
              )
        }

      {:error, reason} ->
        Compilation.add_error(compilation, "Unable to create initialization order: #{reason}")
    end
  end

  def run_phase(compilation) do
    compilation
  end

  def create_init_order(content) do
    content
    |> Enum.filter(fn node ->
      node.game_element == true && Node.node_type(node) != "game"
    end)
    |> InitOrder.initialization_order()
  end
end

defmodule InitOrder do
  @moduledoc """
  Implements a topological sort elements with an identifier that uses the
  $init_after attribute.
  """
  import Rez.Debug
  alias Rez.AST.NodeHelper

  def initialization_order(objects) do
    case objects
         |> build_dependency_graph()
         |> topological_sort() do
      {:ok, order} ->
        {:ok, order}

      {:error, {:missing_dependencies, missing}} ->
        {:error, "Missing required dependencies: #{Enum.join(missing, ", ")}"}

      {:error, :circular_dependency} ->
        {:error, "Circular dependency detected"}
    end
  end

  def build_dependency_graph(objs) do
    graph =
      objs
      |> Enum.filter(fn obj -> Map.has_key?(obj, :id) end)
      |> Enum.map(fn obj ->
        case NodeHelper.get_attr_value(obj, "$init_after", []) do
          [] ->
            {obj.id, []}

          ancestors ->
            {obj.id,
             Enum.map(ancestors, fn {:elem_ref, ancestor_id} -> to_string(ancestor_id) end)}
        end
      end)

    # Debug the initial graph
    d_log("Initial dependency graph")

    Enum.each(graph, fn {id, deps} ->
      d_log("#{id} depends on: #{inspect(deps)}")
    end)

    graph
  end

  def topological_sort(graph) do
    # Start with an empty accumulator for sorted nodes and tracking visited nodes
    sort(graph, [], MapSet.new())
  end

  def sort([], sorted, _visited), do: {:ok, Enum.reverse(sorted)}

  def sort(remaining, sorted, visited) do
    sorted_set = MapSet.new(sorted)

    case find_next_available_node(remaining, sorted_set) do
      nil ->
        if remaining != [] do
          analyze_depedency_errors(remaining, sorted_set)
        else
          {:ok, Enum.reverse(sorted)}
        end

      {object, parents} ->
        remaining = List.delete(remaining, {object, parents})
        sort(remaining, [object | sorted], MapSet.put(visited, object))
    end
  end

  defp analyze_depedency_errors(remaining, sorted_set) do
    # Find all unique dependencies
    all_deps =
      remaining
      |> Enum.flat_map(fn {_id, deps} -> deps end)
      |> MapSet.new()

    # Find missing dependencies (those not in sorted and not in remaining)
    remaining_ids = MapSet.new(Enum.map(remaining, fn {id, _deps} -> id end))

    missing_deps =
      all_deps
      |> Enum.filter(fn dep ->
        !MapSet.member?(sorted_set, dep) && !MapSet.member?(remaining_ids, dep)
      end)

    if missing_deps != [] do
      {:error, {:missing_dependencies, missing_deps}}
    else
      {:error, :circular_dependency}
    end
  end

  # Helper function to find the next node we can process
  defp find_next_available_node(remaining, sorted_set) do
    Enum.find(remaining, fn {_object, parents} ->
      Enum.all?(parents, &MapSet.member?(sorted_set, &1))
    end)
  end
end
