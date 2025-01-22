defmodule Rez.AST.Relationship do
  defstruct status: :ok,
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{}
end

defimpl Rez.AST.Node, for: Rez.AST.Relationship do
  import Rez.AST.NodeValidator

  alias Rez.AST.NodeHelper
  alias Rez.AST.TemplateHelper

  defdelegate js_initializer(relationship), to: NodeHelper

  def node_type(_relationship), do: "relationship"

  def js_ctor(relationship) do
    NodeHelper.get_attr_value(relationship, "$js_ctor", "RezRelationship")
  end

  def default_attributes(_relationship), do: %{}

  def pre_process(relationship), do: relationship

  def process(relationship, _node_map) do
    relationship
    |> TemplateHelper.compile_template_attributes()
  end

  def children(_relationship), do: []

  def validators(_relationship) do
    [
      attribute_present?(
        "source_id",
        attribute_has_type?(
          :elem_ref,
          validate_is_elem?()
        )
      ),
      attribute_present?(
        "target_id",
        attribute_has_type?(
          :elem_ref,
          validate_is_elem?()
        )
      ),
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
end
