defmodule Rez.AST.Layout do
  @moduledoc """
  `Rez.AST.Layout` defines the `Layout` struct.

  A `@layout` is a compile-time directive that lets several `@scene`s (or
  the `@game`) share the same layout by referring to it with
  `layout_id: #layout_id`. During the ApplyDefaults phase the attributes of
  the layout are imported into each element that references it (see
  `Rez.Compiler.LayoutImport`). The `@layout` itself is never written to the
  runtime.
  """
  defstruct status: :ok,
            game_element: false,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{},
            metadata: %{},
            validation: nil

  @allowed_attributes [
    "layout",
    "layout_mode",
    "layout_separator",
    "layout_reverse",
    "bindings",
    "blocks",
    "css_class",
    "on_will_render",
    "on_did_render"
  ]

  @game_attributes [
    "layout",
    "bindings",
    "blocks",
    "css_class",
    "on_will_render",
    "on_did_render"
  ]

  @doc "Attributes that may be defined on a `@layout`."
  def allowed_attributes, do: @allowed_attributes

  @doc "Attributes of a `@layout` that are imported into the `@game`."
  def game_attributes, do: @game_attributes
end

defimpl Rez.AST.Node, for: Rez.AST.Layout do
  def node_type(_layout), do: "layout"

  def js_ctor(_layout), do: raise("@layout does not support a JS constructor!")

  def js_initializer(_layout), do: raise("@layout does not support a JS initializer!")

  def process(layout, _resources), do: layout

  def html_processor(_layout, _attr), do: raise("@layout does not support HTML processors!")
end
