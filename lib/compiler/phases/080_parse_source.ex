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

        error_message = format_errors(reasons)

        error = """
        #{file} L#{logical_line}:#{col}

        #{error_message}

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

  # Infrastructure error codes that wrap more specific errors
  @infrastructure_errors ~w(block_not_matched bad_attr bad_value bad_syntax)a

  defp format_errors(reasons) do
    # Separate semantic errors from infrastructure errors
    {infrastructure, semantic} =
      Enum.split_with(reasons, fn {code, _, _} -> code in @infrastructure_errors end)

    cond do
      # If we have semantic errors, show those prominently
      semantic != [] ->
        semantic
        |> Enum.map(&format_semantic_error/1)
        |> Enum.join("\n")

      # Otherwise fall back to infrastructure errors
      infrastructure != [] ->
        infrastructure
        |> Enum.map(&format_infrastructure_error/1)
        |> Enum.join("\n")

      true ->
        "Unknown parse error"
    end
  end

  defp format_semantic_error({code, _pos, reason}) do
    # Format semantic errors with just the message, code as context
    code_str = code |> Atom.to_string() |> String.replace("_", " ")
    "#{String.capitalize(code_str)}: #{reason}"
  end

  defp format_infrastructure_error({_code, _pos, reason}) do
    # For infrastructure errors, just show the reason
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
end
