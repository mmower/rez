defmodule Rez.Compiler.Phases.GenerateReports do
  alias Rez.Debug

  @moduledoc """
  `Rez.Compiler.Reports` implements the compiler phase that reports on
  progress and/or errors.
  """

  alias Rez.Compiler.Compilation

  def run_phase(%Compilation{status: :ok, progress: progress} = compilation) do
    IO.puts("rez v#{Rez.version()} — #{success_message(compilation)}")

    progress
    |> Enum.reverse()
    |> Enum.each(fn message -> Debug.dbg_log(:verbose, message) end)

    compilation
  end

  def run_phase(%Compilation{status: :error, errors: errors} = compilation) do
    IO.puts("rez v#{Rez.version()} — #{failure_message(compilation)}")

    errors
    |> Enum.reverse()
    |> Enum.each(fn
      {elem, id, error} ->
        IO.puts("In #{elem}##{id}: #{error}")

      error ->
        IO.puts(error)
    end)

    compilation
  end

  defp success_message(%Compilation{options: %{lint: true}}), do: "no errors found"
  defp success_message(_compilation), do: "compiled to dist folder"

  defp failure_message(%Compilation{options: %{lint: true}}), do: "lint failed"
  defp failure_message(_compilation), do: "compilation failed"
end
