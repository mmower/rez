defmodule Rez.Compiler.Phases.ReadSource do
  @moduledoc """
  `Rez.Compiler.ReadSource` uses the `LogicalFile` library to read the game
  source code and process macros handling comments & includes. The result is
  a consolidated source text ready to be parsed.
  """

  alias Rez.Compiler.{Compilation, IOError}
  alias LogicalFile

  @macros [
    LogicalFile.Macros.Include.invocation(expr: ~r/^\s*%\((?<file>.*)\)/),
    Rez.Compiler.CommentMacro.invocation([])
  ]

  @doc """
  Reads the content of the game source and adds it to the compile data under
  the :source key
  """
  def run_phase(
        %Compilation{
          status: :ok,
          options: %{write_source: write_source},
          source_path: source_path,
          progress: progress
        } = compilation
      ) do
    try do
      source = read_source(source_path)

      if write_source, do: File.write("source.rez", to_string(source))

      %{
        compilation
        | source: source,
          progress: ["Read source" | progress]
      }
    rescue
      e in File.Error ->
        IOError.file_read_error(compilation, e.reason, "Game Source", e.path)
    end
  end

  def run_phase(compilation) do
    compilation
  end

  def read_source(source_path) do
    base_path = Path.expand(Path.dirname(source_path))
    file_name = Path.basename(source_path)
    LogicalFile.read(base_path, file_name, @macros)
  end
end
