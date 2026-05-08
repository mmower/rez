defmodule Rez.Compiler.Phases.ApplyDefaults do
  @moduledoc """
  Implements the apply defaults phase of the Rez compiler.

  Iterates AST nodes with a $alias attribute and merges defaults from the alias
  chain into each node.

  ## Handler chaining with `+`

  Event handlers (and any function attribute) support a `+()=>{}` append syntax.
  The rule: `+` at any level means "chain after everything less specific than me."
  Bare `()=>{}` means "replace everything less specific; nothing from those levels runs."

  The alias chain is processed least-specific first so the natural execution order
  is always least-specific → most-specific. Given:

      @defaults object { on_start: +()=>{O} }
      @defaults foo    { on_start: +()=>{F} }   # foo extends object
      @foo f_instance  { on_start: +()=>{I} }

  the compiled handler runs O → F → I.

  Using bare `()=>{}` at any level suppresses everything below it:

      @defaults foo    { on_start:  ()=>{F} }   # replaces O
      @foo f_instance  { on_start: +()=>{I} }   # chains after F only
      # result: F → I
  """
  alias Rez.AST.NodeHelper

  alias Rez.Compiler.Compilation

  def run_phase(%Compilation{status: :ok, content: content, defaults: defaults} = compilation) do
    %{
      compilation
      | content: Enum.map(content, &apply_defaults(&1, defaults))
    }
  end

  def run_phase(compilation), do: compilation

  def apply_defaults(%{game_element: true} = node, defaults) do
    alias_chain = NodeHelper.get_meta(node, "alias_chain", [])

    merged_attrs =
      alias_chain
      |> Enum.reverse()
      |> Enum.reduce(%{}, fn target, acc ->
        case Map.get(defaults, target) do
          nil ->
            acc

          level_defaults ->
            acc
            |> merge_level(level_defaults)
            |> consolidate_merge_sets()
            |> consolidate_append_functions()
        end
      end)
      |> merge_level(node.attributes)
      |> consolidate_merge_sets()
      |> consolidate_append_functions()

    %{node | attributes: merged_attrs}
  end

  def apply_defaults(node, _defaults) do
    node
  end

  # Merges new_attrs (more specific) on top of base_attrs (less specific).
  # new_attrs generally wins; + in new_attrs chains after base.
  defp merge_level(base_attrs, new_attrs) do
    Map.merge(base_attrs, new_attrs, fn _key, base_attr, new_attr ->
      merge_attribute(base_attr, new_attr)
    end)
  end

  # new extends base — chain base first (less specific), new second (more specific)
  defp merge_attribute(
         %{type: :function, value: base_f},
         %{type: :append_function, value: new_f} = new_attr
       ) do
    %{new_attr | type: :function, value: chain_functions(base_f, new_f)}
  end

  # merge_set unions with an existing set
  defp merge_attribute(
         %{type: :set, value: base_set},
         %{type: :merge_set, value: new_values} = new_attr
       ) do
    %{new_attr | type: :set, value: MapSet.union(base_set, new_values)}
  end

  # catch-all: new (more-specific) wins
  defp merge_attribute(_base_attr, new_attr), do: new_attr

  defp chain_functions({kind, base_params, _base_body} = base_f, {_kind2, append_params, append_body}) do
    outer_params = if base_params == [], do: ["_obj", "_evt"], else: base_params
    args = Enum.join(outer_params, ", ")
    base_call = "(#{encode_fn(base_f)})(#{args})"
    append_call = "((#{Enum.join(append_params, ", ")}) => #{append_body})(#{args})"
    {kind, outer_params, "{\n  #{base_call};\n  #{append_call};\n}"}
  end

  defp encode_fn({:arrow, params, body}), do: "(#{Enum.join(params, ", ")}) => #{body}"
  defp encode_fn({:std, params, body}), do: "function(#{Enum.join(params, ", ")}) #{body}"

  defp consolidate_merge_sets(attrs) do
    Map.new(attrs, fn
      {k, %{type: :merge_set} = attr} -> {k, %{attr | type: :set}}
      {k, attr} -> {k, attr}
    end)
  end

  defp consolidate_append_functions(attrs) do
    Map.new(attrs, fn
      {k, %{type: :append_function} = attr} -> {k, %{attr | type: :function}}
      {k, attr} -> {k, attr}
    end)
  end
end
