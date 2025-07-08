defmodule Rez.Compiler.Phases.ParseSource do
  @moduledoc """
  `Rez.Compiler.ParseSource` implements the compiler phase that parses the
  consolidated game content and creates the AST representation from it.
  """

  alias Rez.AST.NodeHelper
  alias LogicalFile
  alias Rez.Compiler.Compilation
  alias Rez.Parser.Parser

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
      {:ok, content, _id_map} ->
        if NodeHelper.first_elem(content, Rez.AST.Game) do
          %{compilation | content: content, progress: ["Compiled source" | progress]}
        else
          Compilation.add_error(compilation, "The @game element is missing.")
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

  # defp translate_code({:bad_syntax, _pos, reason}) do
  #   reason
  # end

  # defp translate_code({:block_not_matched, _pos, reason}) do
  #   "Unable to complete #{reason}"
  # end

  defp translate_code({code, pos, reason}) when is_atom(code) do
    translate_code({Atom.to_string(code), pos, reason})
  end

  defp translate_code({code, pos, reason}) when is_binary(code) do
    "#{code} @ #{inspect(pos)}: #{reason}"
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
end
