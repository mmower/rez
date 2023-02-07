defmodule Rez.AST.Zone do
  @moduledoc """
  `Rez.AST.Zone` defines the `Zone` struct.

  A `Zone` represents a grouping of `Location`s that are narratively close to
  each other.
  """

  alias __MODULE__
  alias Rez.AST.{Attribute, Location}

  defstruct status: :ok,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{},
            locations: %{}

  def add_child(%Location{id: location_id} = location, %Zone{locations: locations} = zone) do
    %{zone | locations: Map.put(locations, location_id, location)}
  end

  def add_child(%Attribute{name: name} = attr, %Zone{attributes: attributes} = zone) do
    %{zone | attributes: Map.put(attributes, name, attr)}
  end
end

defimpl Rez.AST.Node, for: Rez.AST.Zone do
  import Rez.AST.NodeValidator
  alias Rez.AST.{NodeHelper, Zone}

  def node_type(_zone), do: "zone"

  def js_ctor(zone) do
    NodeHelper.get_attr_value(zone, "js_ctor", "RezZone")
  end

  def pre_process(zone), do: zone

  def process(zone), do: NodeHelper.process_collection(zone, :locations)

  def children(%Zone{locations: locations}), do: Map.values(locations)

  def validators(_zone) do
    [
      attribute_if_present?(
        "tags",
        attribute_is_keyword_set?()
      ),
      attribute_present?(
        "name",
        attribute_has_type?(:string)
      ),
      attribute_if_present?(
        "js_ctor",
        attribute_has_type?(:string)
      )
    ]
  end
end
