defmodule Rez.Compiler.Phases.CompileTemplates do
  @moduledoc """
  Compiler phase that compiles source templates in game elements into
  pre-compiled template functions.
  """
  alias Rez.AST.TemplateHelper

  alias Rez.Compiler.Compilation

  def run_phase(
        %Compilation{
          status: :ok,
          content: content
        } = compilation
      ) do
    compiled_content = compile_templates(content)
    compilation = collect_template_errors(compiled_content, compilation)
    %{compilation | content: compiled_content}
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

  defp collect_template_errors(content, compilation) do
    Enum.reduce(content, compilation, fn
      %{status: {:error, errors}, id: id} = _node, compilation ->
        Enum.reduce(errors, compilation, fn error, comp ->
          Compilation.add_error(comp, {:card, id, error})
        end)

      _node, compilation ->
        compilation
    end)
  end
end
