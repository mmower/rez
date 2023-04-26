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
  alias Rez.AST.NodeHelper

  def node_type(_object), do: "object"

  def js_ctor(object) do
    NodeHelper.get_attr_value(object, "js_ctor", "RezObject")
  end

  def default_attributes(_object), do: %{}

  def pre_process(object), do: object

  def process(object), do: object

  def children(_object), do: []

  def validators(_object),
    do: [
      attribute_if_present?(
        "tags",
        attribute_is_keyword_set?()
      ),
      attribute_if_present?(
        "js_ctor",
        attribute_has_type?(:string)
      )
    ]
end
