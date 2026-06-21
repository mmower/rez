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

  defp collect_and_validate_constants(content, %Compilation{keywords: keywords}) do
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

    with {:ok, keyword_constants} <- build_keyword_constants(keywords),
         :ok <- validate_keyword_const_overlap(constants, keyword_constants) do
      all_constants = Map.merge(constants, keyword_constants)

      # Check for conflicts with global elements and reserved names
      case validate_constants(all_constants, global_element_ids, reserved_names) do
        :ok -> {:ok, all_constants}
        {:error, _} = error -> error
      end
    end
  end

  @doc """
  Builds the JS constant name for a keyword: `:big_goblin` becomes `kBigGoblin`
  (the runtime prepends `$`, giving `$kBigGoblin`). Each `_`-separated segment
  has its first character upper-cased and the underscores are dropped.
  """
  def keyword_const_name(keyword) do
    "k" <> (keyword |> String.split("_") |> Enum.map_join("", &upcase_first/1))
  end

  defp upcase_first(""), do: ""

  defp upcase_first(<<first::utf8, rest::binary>>) do
    String.upcase(<<first::utf8>>) <> rest
  end

  # Builds a constants map from the set of keywords used in the source. Returns
  # an error if two distinct keywords map to the same constant name (e.g.
  # :big_goblin and :bigGoblin both -> kBigGoblin).
  defp build_keyword_constants(keywords) do
    grouped = Enum.group_by(MapSet.to_list(keywords), &keyword_const_name/1)

    case Enum.filter(grouped, fn {_name, kws} -> length(kws) > 1 end) do
      [] ->
        {:ok, Map.new(grouped, fn {name, [kw]} -> {name, {:string, kw}} end)}

      collisions ->
        details =
          Enum.map_join(collisions, "; ", fn {name, kws} ->
            "#{Enum.map_join(kws, ", ", &":#{&1}")} all map to $#{name}"
          end)

        {:error, "Keywords map to conflicting constant names (rename one): #{details}"}
    end
  end

  defp validate_keyword_const_overlap(constants, keyword_constants) do
    overlap =
      MapSet.intersection(
        MapSet.new(Map.keys(constants)),
        MapSet.new(Map.keys(keyword_constants))
      )

    if MapSet.size(overlap) == 0 do
      :ok
    else
      conflict_list = overlap |> MapSet.to_list() |> Enum.join(", ")

      {:error,
       "Keyword constants conflict with @const names (rename one): #{conflict_list}"}
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
