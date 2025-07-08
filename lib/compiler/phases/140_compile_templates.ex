defmodule Rez.Compiler.Phases.CompileTemplates do
  @moduledoc """
  Compiler phase that copies the stdlib.rez to the src folder
  @todo Something odd about this...
  """
  alias Rez.AST.TemplateHelper
  alias Rez.AST.NodeHelper

  alias Rez.Compiler.Compilation

  def run_phase(
        %Compilation{
          status: :ok,
          content: content
        } = compilation
      ) do
    %{compilation | content: compile_templates(content)}
  end

  def run_phase(%Compilation{} = compilation) do
    compilation
  end

  def compile_templates(content) do
    Enum.map(
      content,
      fn
        %{game_element: true} = node ->
          TemplateHelper.compile_template_attributes(node)

        node ->
          node
      end
    )
  end
end
