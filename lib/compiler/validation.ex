defmodule Rez.Compiler.Validation do
  @moduledoc """
  `Rez.AST.NodeValidator.Validation` implements the `Validation` struct
  that is passed through the validation pipeline and which collects progress
  and errors as nodes are validated.
  """

  alias Rez.AST.Node

  alias __MODULE__

  defstruct errors: []

  def add_error(%Validation{errors: errors} = validation, node, error) do
    %{validation | errors: [{Node.node_type(node), node.id, error} | errors]}
  end
end
