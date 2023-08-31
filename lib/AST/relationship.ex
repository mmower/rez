defmodule Rez.AST.Relationship do
  alias __MODULE__
  alias Rez.AST.Attribute
  alias Rez.AST.NodeHelper

  defstruct status: :ok,
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{}

  def make(source_id, target_id, affinity, tags \\ MapSet.new()) do
    auto_id = "rel_#{source_id}_#{target_id}"

    %Relationship{id: auto_id}
    |> NodeHelper.set_elem_ref_attr("source", source_id)
    |> NodeHelper.set_elem_ref_attr("target", target_id)
    |> NodeHelper.set_attr(Attribute.create("affinity", affinity))
    |> NodeHelper.set_set_attr("tags", tags)
  end
end

defimpl Rez.AST.Node, for: Rez.AST.Relationship do
  import Rez.AST.NodeValidator

  alias Rez.AST.NodeHelper
  alias Rez.AST.TemplateHelper

  defdelegate js_initializer(relationship), to: NodeHelper

  def node_type(_relationship), do: "relationship"

  def js_ctor(relationship) do
    NodeHelper.get_attr_value(relationship, "js_ctor", "RezRelationship")
  end

  def default_attributes(_relationship), do: %{}

  def pre_process(relationship), do: relationship

  def process(relationship, node_map) do
    relationship
    |> NodeHelper.copy_attributes(node_map)
    |> TemplateHelper.compile_template_attributes()
  end

  def children(_relationship), do: []

  def validators(_relationship) do
    [
      attribute_present?(
        "source",
        attribute_has_type?(
          :elem_ref,
          validate_is_elem?()
        )
      ),
      attribute_present?(
        "target",
        attribute_has_type?(
          :elem_ref,
          validate_is_elem?()
        )
      ),
      attribute_present?(
        "affinity",
        attribute_has_type?(
          :number,
          value_passes?(
            fn value -> value >= -5.0 and value <= 5.0 end,
            "Affinity values must be between -5.0 .. +5.0"
          )
        )
      ),
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
end
