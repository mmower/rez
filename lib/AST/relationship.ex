defmodule Rez.AST.Relationship do
  defstruct [
    status: :ok,
    position: {nil, 0, 0},
    id: nil,
    attributes: %{},
  ]
end

defimpl Rez.AST.Node, for: Rez.AST.Relationship do
  import Rez.AST.NodeValidator

  def node_type(_relationship), do: "relationship"

  def pre_process(relationship), do: relationship

  def process(relationship), do: relationship

  def children(_relationship), do: []

  def validators(_relationship) do
    [
      attribute_present?("source",
        attribute_has_type?(:elem_ref,
          validate_is_elem?())),

      attribute_present?("target",
        attribute_has_type?(:elem_ref,
          validate_is_elem?())),

      attribute_present?("affinity",
        attribute_has_type?(:number,
          value_passes?(
            fn value -> value >= -5.0 and value <= 5.0 end,
            "Affinity values must be between -5.0 .. +5.0"))),

      attribute_if_present?("tags",
        attribute_is_keyword_set?()),
    ]
  end
end
