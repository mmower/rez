defmodule Rez.AST.List do
  @moduledoc """
  `Rez.AST.List` defines the `List` struct.

  A `List` represents a list of values. For example a list of
  options for character names.
  """

  defstruct status: :ok,
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{}
end

defimpl Rez.AST.Node, for: Rez.AST.List do
  import Rez.AST.NodeValidator

  alias Rez.AST.Attribute
  alias Rez.AST.NodeHelper
  alias Rez.AST.TemplateHelper

  defdelegate js_initializer(list), to: NodeHelper

  def node_type(_list), do: "list"

  def js_ctor(list) do
    NodeHelper.get_attr_value(list, "$js_ctor", "RezList")
  end

  def default_attributes(_list),
    do: %{
      "$auto_id_idx" => Attribute.number("$auto_id_idx", 0)
    }

  def pre_process(list), do: list

  def process(list, _node_map) do
    list
    |> TemplateHelper.compile_template_attributes()
  end

  def children(_list), do: []

  def validators(_list) do
    [
      attribute_if_present?(
        "$init_after",
        attribute_has_type?(:list, attribute_coll_of?(:elem_ref))
      ),
      attribute_if_present?(
        "tags",
        attribute_is_keyword_set?()
      ),
      attribute_present?(
        "values",
        attribute_has_type?(:list)
      ),
      attribute_if_present?(
        "$js_ctor",
        attribute_has_type?(:string)
      )
    ]
  end
end
