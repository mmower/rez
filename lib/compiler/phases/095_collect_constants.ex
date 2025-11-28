defmodule Rez.Compiler.Phases.CollectConstants do
  @moduledoc """
  Collects @const declarations from the AST and validates for naming conflicts.

  This phase:
  1. Extracts all Rez.AST.Const nodes into a constants table
  2. Validates that constant names don't conflict with:
     - Other constants
     - Element IDs with $global: true
     - Reserved runtime names ($game, etc.)
  """
  alias Rez.Compiler.Compilation
  alias Rez.AST.NodeHelper

  def run_phase(%Compilation{status: :ok, content: content, progress: progress} = compilation) do
    case collect_and_validate_constants(content, compilation) do
      {:ok, constants} ->
        %{
          compilation
          | constants: constants,
            progress: ["Collected constants" | progress]
        }

      {:error, error} ->
        Compilation.add_error(compilation, error)
    end
  end

  def run_phase(%Compilation{status: :error} = compilation), do: compilation

  defp collect_and_validate_constants(content, _compilation) do
    # Extract all constants from AST
    constants =
      content
      |> Enum.filter(&match?(%Rez.AST.Const{}, &1))
      |> Enum.reduce(%{}, fn const, acc ->
        Map.put(acc, const.name, const.value)
      end)

    # Get all element IDs with $global: true for conflict checking
    global_element_ids = get_global_element_ids(content)

    # Reserved runtime names that constants cannot use
    reserved_names = ["game"]

    # Check for conflicts
    case validate_constants(constants, global_element_ids, reserved_names) do
      :ok -> {:ok, constants}
      {:error, _} = error -> error
    end
  end

  defp get_global_element_ids(content) do
    content
    |> Enum.filter(& &1.game_element)
    |> Enum.filter(&(NodeHelper.get_attr_value(&1, "$global") == true))
    |> Enum.map(&Map.get(&1, :id, nil))
    |> Enum.reject(&is_nil/1)
  end

  defp validate_constants(constants, global_element_ids, reserved_names) do
    const_names = Map.keys(constants)

    # Check for conflicts with global elements
    global_conflicts = Enum.filter(const_names, fn name -> name in global_element_ids end)

    if length(global_conflicts) > 0 do
      conflict_list = Enum.join(global_conflicts, ", ")
      {:error, "Constant names conflict with global elements: #{conflict_list}"}
    else
      # Check for conflicts with reserved names
      reserved_conflicts = Enum.filter(const_names, fn name -> name in reserved_names end)

      if length(reserved_conflicts) > 0 do
        conflict_list = Enum.join(reserved_conflicts, ", ")
        {:error, "Constant names conflict with reserved runtime names: #{conflict_list}"}
      else
        :ok
      end
    end
  end
end
