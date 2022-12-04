defmodule Rez.Compiler.ValidateNodes do
  @moduledoc """
  `Rez.Compiler.ValidateNodes` implements the compiler phase that validates
  the game AST nodes logging errors into the `Compilation` as appropriate.
  """

  alias Rez.Compiler.Compilation
  alias Rez.AST.{NodeHelper, NodeValidator}

  def run_phase(%Compilation{status: :ok, game: game} = compilation) do
    case NodeValidator.validate_root(game) do
      %{errors: []} ->
        compilation

      %{errors: errors} ->
        Enum.reduce(errors, compilation, fn {node, error}, compilation ->
          Compilation.add_error(compilation, "#{NodeHelper.description(node)}: #{error}")
        end)
    end
  end

  def run_phase(%Compilation{} = compilation) do
    compilation
  end
end
