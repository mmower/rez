defmodule Rez.Compiler.LayoutImport do
  @moduledoc """
  Support for importing a compile-time `@layout` into the `@scene` or `@game`
  that references it with `layout_id: #layout_id`.

  The import happens in the ApplyDefaults phase. The layout's attributes form a
  level of their own between the `@defaults` of the element's alias chain and
  the element's own attributes:

      @defaults scene -> @defaults <alias> -> @layout -> element attributes

  The `layout_id` must be a literal element reference (constants and tag
  references are resolved after ApplyDefaults). After the import `layout_id`
  is removed and replaced by `$layout_reference`, the id of the layout, which
  is used to attribute errors to the layout they came from.

  `bindings:` and `blocks:` are merged rather than replaced: the layout's
  entries come first and an element entry with the same prefix replaces the
  layout entry in place; the element's remaining entries follow.
  """
  alias Rez.AST.{Attribute, Game, Layout, NodeHelper}

  @reference_attr "$layout_reference"
  @merged_list_attrs ["bindings", "blocks"]

  @doc "Name of the attribute that records which @layout an element imported."
  def reference_attr, do: @reference_attr

  @doc """
  Returns a map of layout id to `%Layout{}` for every `@layout` in `content`.
  """
  def layouts(content) when is_list(content) do
    content
    |> Enum.filter(&is_struct(&1, Layout))
    |> Map.new(&{&1.id, &1})
  end

  @doc """
  Validates the `@layout` directives themselves, returning a list of error
  messages: nested layouts are not supported and only layout attributes may
  be defined.
  """
  def validate_layouts(%{} = layouts) do
    layouts
    |> Map.values()
    |> Enum.sort_by(& &1.id)
    |> Enum.flat_map(&validate_layout/1)
  end

  defp validate_layout(%Layout{} = layout) do
    nested_errors =
      if NodeHelper.has_attr?(layout, "layout_id") do
        ["#{describe(layout)}: a @layout cannot use layout_id, nested layouts are not supported"]
      else
        []
      end

    disallowed =
      layout
      |> NodeHelper.attr_names()
      |> Enum.reject(&(&1 in Layout.allowed_attributes() or &1 == "layout_id"))
      |> Enum.sort()

    disallowed_errors =
      case disallowed do
        [] ->
          []

        names ->
          [
            "#{describe(layout)}: attribute(s) #{Enum.join(names, ", ")} not allowed in a @layout " <>
              "(allowed: #{Enum.join(Layout.allowed_attributes(), ", ")})"
          ]
      end

    nested_errors ++ disallowed_errors
  end

  @doc """
  Determines which layout, if any, `node` refers to. The `layout_id` is looked
  for in the element's own attributes and then in its merged `@defaults`.

  Returns `:none`, `{:ok, layout_id, layout_attrs}` where `layout_attrs` are
  the attributes to import, or `{:error, message}`.
  """
  def resolve(node, defaults_merged, layouts) do
    case Map.get(node.attributes, "layout_id") || Map.get(defaults_merged, "layout_id") do
      nil ->
        :none

      %Attribute{type: :elem_ref, value: layout_id} ->
        case Map.get(layouts, layout_id) do
          nil ->
            {:error, "#{describe(node)}: layout_id refers to unknown @layout ##{layout_id}"}

          %Layout{} = layout ->
            import_attrs(node, layout)
        end

      %Attribute{} ->
        {:error,
         "#{describe(node)}: layout_id must be a literal element reference to a @layout, e.g. layout_id: #l_main"}
    end
  end

  defp import_attrs(%Game{} = game, %Layout{id: layout_id, attributes: attrs}) do
    case Map.get(attrs, "layout_mode") do
      %Attribute{value: mode} when mode != "single" ->
        {:error,
         "#{describe(game)}: @game can only use a single layout (@layout #{layout_id} has layout_mode: :#{mode})"}

      _ ->
        {:ok, layout_id, Map.take(attrs, Layout.game_attributes())}
    end
  end

  defp import_attrs(_node, %Layout{id: layout_id, attributes: attrs}) do
    {:ok, layout_id, Map.take(attrs, Layout.allowed_attributes())}
  end

  @doc """
  Prepares the element's own attributes for merging over the layout level:
  where both the layout and the element define `bindings:` or `blocks:` the
  element's list is replaced by the merged list.
  """
  def merge_element_attrs(element_attrs, layout_attrs) do
    Enum.reduce(@merged_list_attrs, element_attrs, fn name, attrs ->
      case {Map.get(layout_attrs, name), Map.get(attrs, name)} do
        {%Attribute{type: :list, value: layout_list}, %Attribute{type: :list, value: elem_list} = attr} ->
          Map.put(attrs, name, %{attr | value: merge_binding_list(layout_list, elem_list)})

        _ ->
          attrs
      end
    end)
  end

  @doc """
  Merges two binding lists. Entries of `layout_list` come first; an entry of
  `elem_list` with the same prefix replaces it in place, and the remaining
  entries of `elem_list` follow in their original order.
  """
  def merge_binding_list(layout_list, elem_list) do
    elem_by_prefix =
      elem_list
      |> Enum.flat_map(fn
        {:list_binding, {prefix, _}} = binding -> [{prefix, binding}]
        _ -> []
      end)
      |> Map.new()

    {merged, used} =
      Enum.map_reduce(layout_list, MapSet.new(), fn
        {:list_binding, {prefix, _}} = binding, used ->
          case Map.fetch(elem_by_prefix, prefix) do
            {:ok, replacement} -> {replacement, MapSet.put(used, prefix)}
            :error -> {binding, used}
          end

        other, used ->
          {other, used}
      end)

    rest =
      Enum.reject(elem_list, fn
        {:list_binding, {prefix, _}} -> MapSet.member?(used, prefix)
        _ -> false
      end)

    merged ++ rest
  end

  @doc """
  Removes `layout_id` from the merged attributes and records the layout that
  was imported in `$layout_reference`.
  """
  def finalize(attrs, layout_id) do
    attrs
    |> Map.delete("layout_id")
    |> Map.put(@reference_attr, Attribute.string(@reference_attr, layout_id))
  end

  @doc """
  Returns `message` with a note of the `@layout` it came from appended if
  `node` imported a layout.
  """
  def attribute_error(node, message) do
    case NodeHelper.get_attr_value(node, @reference_attr) do
      nil -> message
      layout_id -> "#{message} (Layout came from @layout #{layout_id})"
    end
  end

  defp describe(%{position: {file, _, _}} = node) when is_binary(file),
    do: NodeHelper.description(node)

  defp describe(%{id: id} = node), do: "#{Rez.AST.Node.node_type(node)}/#{id}"
end
