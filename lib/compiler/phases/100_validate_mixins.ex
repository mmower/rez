defmodule Rez.Compiler.Phases.ValidateMixins do
  @moduledoc """
  Implements the validate mixins phase of the Rez compiler.

  It checks every AST node that declares the id of mixins it wants to incorporate
  and validates that the named mixin exists as a Mixin AST node.
  """
  alias Rez.AST.NodeHelper
  alias Rez.Compiler.Compilation

  def run_phase(%Compilation{status: :ok, content: content} = compilation) do
    {mixins, content} = Enum.split_with(content, &is_struct(&1, Rez.AST.Mixin))
    game_content = Enum.filter(content, & &1.game_element)
    mixin_ids = Enum.map(mixins, & &1.id)

    Enum.reduce(game_content, compilation, fn content_node, compilation ->
      case get_missing_mixins(content_node, mixin_ids) do
        [] ->
          compilation

        missing ->
          # missing = Enum.map_join(missing, ", ", fn {:elem_ref, mixin} -> to_string(mixin) end)
          Compilation.add_error(
            compilation,
            "#{NodeHelper.description(content_node)} missing mixins: #{missing}"
          )
      end
    end)
  end

  def run_phase(compilation) do
    compilation
  end

  def get_missing_mixins(node, mixin_ids) do
    case NodeHelper.get_attr_value(node, "$mixins", []) do
      [] ->
        []

      node_mixins when is_list(node_mixins) ->
        node_mixins = Enum.map(node_mixins, fn {:elem_ref, mixin} -> mixin end)
        # Find any of this mixin ids that isn't in the list of mixin_ids
        node_mixins -- mixin_ids
    end
  end
end
