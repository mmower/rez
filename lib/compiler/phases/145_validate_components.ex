defmodule Rez.Compiler.Phases.ValidateComponents do
  @moduledoc """
  Compiler phase that validates all component references in compiled templates.

  After templates are compiled (phase 140), this phase scans the generated JS
  for `window.Rez.user_components.<name>` references and verifies that each
  referenced component name corresponds to a defined @component element.
  """

  alias Rez.AST.Component
  alias Rez.AST.Attribute
  alias Rez.AST.NodeHelper
  alias Rez.Compiler.Compilation

  @component_ref_pattern ~r/window\.Rez\.user_components\.(\w+)/

  def run_phase(%Compilation{status: :ok, content: content} = compilation) do
    component_names =
      content
      |> Enum.filter(&is_struct(&1, Component))
      |> MapSet.new(& &1.name)

    content
    |> Enum.filter(& &1.game_element)
    |> Enum.reduce(compilation, fn node, comp ->
      validate_node_components(node, component_names, comp)
    end)
  end

  def run_phase(compilation), do: compilation

  defp validate_node_components(node, component_names, compilation) do
    node.attributes
    |> Enum.reduce(compilation, fn
      {_name, %Attribute{type: :compiled_template, value: js}}, comp when is_binary(js) ->
        validate_template_refs(node, js, component_names, comp)

      _, comp ->
        comp
    end)
  end

  defp validate_template_refs(node, js, component_names, compilation) do
    @component_ref_pattern
    |> Regex.scan(js)
    |> Enum.reduce(compilation, fn [_match, name], comp ->
      if MapSet.member?(component_names, name) do
        comp
      else
        Compilation.add_error(
          comp,
          "#{NodeHelper.description(node)} references undefined @component '#{name}'"
        )
      end
    end)
  end
end
