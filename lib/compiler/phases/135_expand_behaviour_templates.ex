defmodule Rez.Compiler.Phases.ExpandBehaviourTemplates do
  @moduledoc """
  Implements the compiler phase that expands `@behaviour_template` references
  within behaviour-tree (`:bht`) attributes.

  A behaviour tree can refer to a named template using the `&template_id`
  syntax, which the parser represents as `{:template, template_id}`. This phase
  collects all `@behaviour_template` definitions and replaces each reference
  with the (recursively expanded) template body so that the value encoder only
  ever sees concrete `{behaviour_id, options, children}` nodes.
  """
  alias Rez.Compiler.Compilation
  alias Rez.AST.BehaviourTemplate
  alias Rez.AST.NodeHelper

  def run_phase(%Compilation{status: :ok, content: content, progress: progress} = compilation) do
    templates =
      content
      |> Enum.filter(fn
        %BehaviourTemplate{} -> true
        _ -> false
      end)
      |> Map.new(fn %BehaviourTemplate{id: id, template: template} -> {id, template} end)

    expanded =
      Enum.map(content, fn
        %{attributes: _attributes} = node ->
          NodeHelper.expand_behaviour_templates(node, templates)

        node ->
          node
      end)

    %{
      compilation
      | content: expanded,
        progress: ["Expanded behaviour templates" | progress]
    }
  end

  def run_phase(compilation) do
    compilation
  end
end
