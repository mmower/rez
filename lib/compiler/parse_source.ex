defmodule Rez.Compiler.ParseSource do
  @moduledoc """
  `Rez.Compiler.ParseSource` implements the compiler phase that parses the
  consolidated game content and creates the AST representation from it.
  """

  alias Rez.Compiler.Compilation
  alias Rez.Parser.Parser
  alias Rez.AST.Game

  @doc """
  Parses the game source into a list of AST nodes that it adds to the
  compilation data under the nodes: key
  """
  def run_phase(
        %Compilation{
          status: :ok,
          source: source,
          progress: progress
        } = compilation
      ) do
    case Parser.parse(source) do
      {:ok, %Game{status: :ok} = game, id_map} ->
        case validate_id_map(id_map) do
          [] ->
            %{
              compilation
              | game: %{game | id_map: id_map},
                progress: ["Compiled source" | progress]
            }

          errors when is_list(errors) ->
            Enum.reduce(errors, compilation, fn {id, mappings}, compilation ->
              Compilation.add_error(
                compilation,
                "Multiple attempts to define id #{id} -> " <>
                  Enum.map_join(mappings, ", ", fn {label, file, line} ->
                    "#{label}@#{file}:#{line}"
                  end))
            end)
        end

      {:ok, %Game{status: {:error, reason}}, _id_map} ->
        Compilation.add_error(compilation, reason)

      {:error, reasons, line, col, _input} ->
        context = source_context(source, line, col)
        reasons = Enum.map_join(reasons, "\n", fn {_line, _col, reason} -> reason end)
        Compilation.add_error(compilation, "L#{line}:#{col} Unable to compile source: #{reasons}\n#{context}")
    end
  end

  def run_phase(compilation) do
    compilation
  end

  defp source_context(source, line, col) do
    first_line = max(0, line - 2)
    last_line = min(line + 2, LogicalFile.last_line_number(source))
    (first_line .. last_line)
      |> Enum.map(fn lno -> {lno, LogicalFile.line(source, lno)} end)
      |> List.insert_at(3, {"", "#{String.duplicate(" ", col)}^"})
      |> Enum.reject(fn {_, line} -> is_nil(line) end)
      |> Enum.map_join("\n", fn {lno, line} -> "#{lno}> #{line}" end)
  end

  defp validate_id_map(id_map) do
    Enum.filter(id_map, fn {_id, mapping} -> is_list(mapping) end)
  end
end
