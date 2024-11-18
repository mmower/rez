defmodule Rez.Compiler.ParseSource do
  @moduledoc """
  `Rez.Compiler.ParseSource` implements the compiler phase that parses the
  consolidated game content and creates the AST representation from it.
  """

  alias LogicalFile
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
      {:ok, content, id_map} ->
        case find_duplicate_id_definitions(id_map) do
          [] ->
            case build_game(content, id_map) do
              {:error, message} ->
                Compilation.add_error(compilation, message)

              %Game{status: {:error, reason}} ->
                Compilation.add_error(compilation, reason)

              game ->
                compilation
                |> Map.put(:game, game)
                |> Map.put(:id_map, id_map)
                |> Map.put(:progress, ["Compiled source" | progress])
            end

          errors when is_list(errors) ->
            Enum.reduce(errors, compilation, fn {id, mappings}, compilation ->
              Compilation.add_error(
                compilation,
                "Multiple attempts to define id #{id} -> " <>
                  Enum.map_join(mappings, ", ", fn {label, file, line} ->
                    "#{label}@#{file}:#{line}"
                  end)
              )
            end)
        end

      {:error, reasons, line, col, _input} ->
        {file, logical_line} = LogicalFile.resolve_line(source, line)
        context = source_context(source, line, col)

        reasons = Enum.map_join(reasons, "\n", &translate_code/1)

        error = """
        #{file} L#{logical_line}:#{col}\n
        Compilation failed:
        #{reasons}\n
        #{context}
        """

        Compilation.add_error(
          compilation,
          error
        )
    end
  end

  def run_phase(compilation) do
    compilation
  end

  defp translate_code({:bad_syntax, _pos, reason}) do
    reason
  end

  defp translate_code({:block_not_matched, _pos, reason}) do
    "Unable to complete #{reason}"
  end

  defp translate_code({:unexpected_char, _pos, reason}) do
    reason
  end

  defp source_context(source, line, col) do
    first_line = max(0, line - 2)
    last_line = min(line + 2, LogicalFile.last_line_number(source))

    first_line..last_line
    |> Enum.map(fn lno ->
      {_file, l_lno} = LogicalFile.resolve_line(source, lno)
      {l_lno, LogicalFile.line(source, lno)}
    end)
    |> List.insert_at(3, {"", "#{String.duplicate(" ", col)}^"})
    |> Enum.reject(fn {_, line} -> is_nil(line) end)
    |> Enum.map_join("\n", fn {lno, line} -> "#{lno}> #{line}" end)
  end

  def build_game(content, id_map) when is_list(content) and is_map(id_map) do
    case sort_game_and_content(content) do
      {[], _} ->
        {:error, "No @game element defined."}

      {[game], elems_and_directives} ->
        Enum.reduce(elems_and_directives, %{game | id_map: id_map}, fn e, game ->
          Game.add_child(e, game)
        end)
    end
  end

  defp sort_game_and_content(content) when is_list(content) do
    Enum.split_with(content, &is_struct(&1, Rez.AST.Game))
  end

  # Filter the id_map values for lists. A list means multiple attempts
  # to define a given ID
  defp find_duplicate_id_definitions(id_map) do
    Enum.filter(id_map, fn {_id, mapping} -> is_list(mapping) end)
  end
end
