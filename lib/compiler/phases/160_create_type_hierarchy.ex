defmodule Rez.Compiler.Phases.CreateTypeHierarchy do
  @moduledoc """
  Implements the create type hierarchy phase of the Rez compiler.

  This looks for all Derive AST nodes and creates a hierarchy of such nodes
  that are then added to the compilation.
  """
  alias Rez.Compiler.Compilation
  alias Rez.AST.NodeHelper
  alias Rez.AST.TypeHierarchy

  def run_phase(%Compilation{status: :ok, content: content} = compilation) do
    %{compilation | type_hierarchy: create_type_hierarchy(content)}
  end

  def run_phase(compilation) do
    compilation
  end

  def create_type_hierarchy(content) do
    content
    |> NodeHelper.filter_elem(Rez.AST.Derive)
    |> Enum.reduce(
      %{},
      fn
        %Rez.AST.Derive{tag: tag, parent: parent_tag}, types ->
          TypeHierarchy.add(types, tag, parent_tag)
      end
    )
  end
end
