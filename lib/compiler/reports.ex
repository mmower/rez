defmodule Rez.Compiler.Reports do
  alias Rez.Debug

  @moduledoc """
  `Rez.Compiler.Reports` implements the compiler phase that reports on
  progress and/or errors.
  """

  alias Rez.Compiler.Compilation

  def run_phase(%Compilation{status: :ok, progress: progress} = compilation) do
    IO.puts("rez v#{Rez.version()} — compiled to dist folder")

    progress
    |> Enum.reverse()
    |> Enum.each(fn message -> Debug.dbg_log(:verbose, message) end)

    compilation
  end

  def run_phase(%Compilation{status: :error, errors: errors} = compilation) do
    IO.puts("rez v#{Rez.version()} — compilation failed")

    errors
    |> Enum.reverse()
    |> Enum.each(fn error -> IO.puts(error) end)

    compilation
  end
end
