defmodule Rez.Compiler.Validation do
  @moduledoc """
  `Rez.AST.NodeValidator.Validation` implements the `Validation` struct
  that is passed through the validation pipeline and which collects progress
  and errors as nodes are validated.
  """

  alias Rez.AST.Node
  alias Rez.AST.NodeHelper

  alias __MODULE__

  defstruct errors: []

  def add_error(%Validation{errors: errors} = validation, node, error) do
    error =
      if NodeHelper.has_id?(node) do
        "#{Node.node_type(node)}##{node.id}: #{error}"
      else
        "#{Node.node_type(node)}: #{error}"
      end

    %{validation | errors: [{Node.node_type(node), node.id, error} | errors]}
  end

  # def merge(
  #       %Validation{errors: parent_errors, validated: parent_validated} = parent_validation,
  #       %Validation{errors: child_errors, validated: child_validated}
  #     ) do
  #   %{
  #     parent_validation
  #     | errors: parent_errors ++ child_errors,
  #       validated: parent_validated ++ child_validated
  #   }
  # end
end
