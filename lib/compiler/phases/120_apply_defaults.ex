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

  ## Layouts

  An element that references a `@layout` with `layout_id:` has the layout's
  attributes imported as an extra level between its `@defaults` and its own
  attributes. See `Rez.Compiler.LayoutImport`.
  """
  alias Rez.AST.NodeHelper

  alias Rez.Compiler.Compilation
  alias Rez.Compiler.LayoutImport

  def run_phase(%Compilation{status: :ok, content: content, defaults: defaults} = compilation) do
    layouts = LayoutImport.layouts(content)

    compilation =
      layouts
      |> LayoutImport.validate_layouts()
      |> Enum.reduce(compilation, &Compilation.add_error(&2, &1))

    {content, compilation} =
      Enum.map_reduce(content, compilation, fn node, compilation ->
        case apply_defaults(node, defaults, layouts) do
          {:ok, node} -> {node, compilation}
          {:error, node, message} -> {node, Compilation.add_error(compilation, message)}
        end
      end)

    %{compilation | content: content}
  end

  def run_phase(compilation), do: compilation

  @doc """
  Applies the defaults of the node's alias chain to the node, without
  importing any `@layout`. See `apply_defaults/3`.
  """
  def apply_defaults(%{game_element: true} = node, defaults) do
    merge_attrs(node, merge_alias_chain_defaults(node, defaults), nil)
  end

  def apply_defaults(node, _defaults), do: node

  @doc """
  Applies the defaults of the node's alias chain to the node and imports the
  `@layout` it references with `layout_id` (if any). The layout sits between
  the defaults and the node's own attributes (see `Rez.Compiler.LayoutImport`).

  Returns `{:ok, node}` or `{:error, node, message}`. On error the node has
  had its defaults applied but no layout imported.
  """
  def apply_defaults(%{game_element: true} = node, defaults, layouts) do
    defaults_merged = merge_alias_chain_defaults(node, defaults)

    case LayoutImport.resolve(node, defaults_merged, layouts) do
      :none ->
        {:ok, merge_attrs(node, defaults_merged, nil)}

      {:ok, layout_id, layout_attrs} ->
        {:ok, merge_attrs(node, defaults_merged, {layout_id, layout_attrs})}

      {:error, message} ->
        {:error, merge_attrs(node, defaults_merged, nil), message}
    end
  end

  def apply_defaults(node, _defaults, _layouts), do: {:ok, node}

  defp merge_alias_chain_defaults(node, defaults) do
    node
    |> NodeHelper.get_meta("alias_chain", [])
    |> Enum.reverse()
    |> Enum.reduce(%{}, fn target, acc ->
      case Map.get(defaults, target) do
        nil -> acc
        level_defaults -> merge_level_and_consolidate(acc, level_defaults)
      end
    end)
  end

  defp merge_attrs(node, defaults_merged, nil) do
    merged_attrs =
      defaults_merged
      |> merge_level_and_consolidate(node.attributes)
      |> tag_from_defaults(defaults_merged, node.attributes)

    %{node | attributes: merged_attrs}
  end

  # The layout is the most specific level below the node itself. Attributes
  # imported from it are tagged as coming from defaults, so that shared
  # handlers are de-duplicated in the runtime.
  defp merge_attrs(node, defaults_merged, {layout_id, layout_attrs}) do
    base_attrs = merge_level_and_consolidate(defaults_merged, layout_attrs)
    element_attrs = LayoutImport.merge_element_attrs(node.attributes, layout_attrs)

    merged_attrs =
      base_attrs
      |> merge_level_and_consolidate(element_attrs)
      |> tag_from_defaults(base_attrs, element_attrs)
      |> LayoutImport.finalize(layout_id)

    %{node | attributes: merged_attrs}
  end

  defp merge_level_and_consolidate(base_attrs, new_attrs) do
    base_attrs
    |> merge_level(new_attrs)
    |> consolidate_merge_sets()
    |> consolidate_append_functions()
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

  # Marks attrs that came only from @defaults (not overridden by the element itself).
  defp tag_from_defaults(merged_attrs, defaults_merged, element_attrs) do
    Map.new(merged_attrs, fn {name, attr} ->
      is_default_only =
        Map.has_key?(defaults_merged, name) and not Map.has_key?(element_attrs, name)

      {name, %{attr | from_defaults: is_default_only}}
    end)
  end

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
