defmodule Rez.AST.Behaviour do
  @moduledoc """
  `Rez.AST.Behaviour` contains the `Behaviour` struct and its `Node` implementation.

  A `Behaviour` is used to represent an action or condition used in a behaviour tree.
  """

  defstruct status: :ok,
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{}
end

defimpl Rez.AST.Node, for: Rez.AST.Behaviour do
  import Rez.AST.NodeValidator

  alias Rez.AST.Attribute
  alias Rez.AST.NodeHelper
  alias Rez.AST.TemplateHelper

  defdelegate js_initializer(behaviour), to: NodeHelper

  def node_type(_behaviour), do: "behaviour"

  def js_ctor(behaviour) do
    NodeHelper.get_attr_value(behaviour, "$js_ctor", "RezBehaviour")
  end

  def default_attributes(_behaviour),
    do: %{
      "$auto_id_idx" => Attribute.number("$auto_id_idx", 0),
      "options" => Attribute.list("options", []),
      "expected_keys" => Attribute.list("expected_keys", []),
      "min_children" => Attribute.number("min_children", 0),
      "max_children" => Attribute.number("max_children", 0),
      "owner_id" => Attribute.elem_ref("owner_id", "")
    }

  def pre_process(behaviour), do: behaviour

  def process(behaviour, %{by_id: node_map}) do
    behaviour
    |> NodeHelper.copy_attributes(node_map)
    |> TemplateHelper.compile_template_attributes()
  end

  def children(_behaviour), do: []

  def validators(_behaviour) do
    [
      attribute_if_present?(
        "options",
        attribute_has_type?(
          :list,
          attribute_coll_of?(:keyword)
        )
      ),
      attribute_if_present?(
        "expected_keys",
        attribute_has_type?(
          :list,
          attribute_coll_of?(:keyword)
        )
      ),
      attribute_present?(
        "execute",
        attribute_has_type?(
          :function,
          validate_expects_params?(["owner", "behaviour", "wmem"])
        )
      ),
      attribute_if_present?(
        "min_children",
        attribute_has_type?(:number)
      ),
      attribute_if_present?(
        "max_children",
        attribute_has_type?(:number)
      ),
      attribute_if_present?(
        "$js_ctor",
        attribute_has_type?(:string)
      )
    ]
  end
end
