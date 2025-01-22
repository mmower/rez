defmodule Rez.AST.Object do
  @moduledoc """
  Defines the `%Object{}` structure. An Object is an author-defined structure
  and has no built-in meaning or runtime functionality.
  """

  defstruct status: :ok,
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{}
end

defimpl Rez.AST.Node, for: Rez.AST.Object do
  import Rez.AST.NodeValidator

  alias Rez.AST.Attribute
  alias Rez.AST.NodeHelper
  alias Rez.AST.TemplateHelper

  defdelegate js_initializer(object), to: NodeHelper

  def node_type(_object), do: "object"

  def js_ctor(object) do
    NodeHelper.get_attr_value(object, "$js_ctor", "RezObject")
  end

  def default_attributes(_object),
    do: %{
      "$auto_id_idx" => Attribute.number("$auto_id_idx", 0)
    }

  def pre_process(object), do: object

  def process(object, _node_map) do
    object
    |> TemplateHelper.compile_template_attributes()
  end

  def children(_object), do: []

  def validators(_object),
    do: [
      attribute_if_present?(
        "tags",
        attribute_is_keyword_set?()
      ),
      attribute_if_present?(
        "$js_ctor",
        attribute_has_type?(:string)
      )
    ]
end
