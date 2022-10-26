defmodule Rez.Compiler.Compilation do
  alias __MODULE__
  alias Rez.AST.Game

  @moduledoc """
  `Rez.Compiler.Compilation` defines the `Compilation` struct.

  `Compilation` is used to track progress of the compiler and its results.
  """
  defstruct status: :ok,
            options: %{},
            phase: nil,
            source: nil,
            source_path: nil,
            path: nil,
            dist_path: nil,
            cache_path: nil,
            handlebars_cmd: nil,
            game: nil,
            progress: [],
            errors: []

  def set_game(%Compilation{} = compilation, %Game{} = game) do
    %{compilation | game: game}
  end

  def add_error(%__MODULE__{errors: errors} = compilation, error) do
    %{compilation | status: :error, errors: [error | errors]}
  end

  def verbose?(%__MODULE__{options: %{verbose: flag}}), do: flag

  def ignore_missing_assets?(%__MODULE__{options: %{ignore_missing_assets: flag}}), do: flag

end
