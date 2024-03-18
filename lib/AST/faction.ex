defmodule Rez.AST.Faction do
  @moduledoc """
  `Rez.AST.Faction` contains the `Faction` struct that is used to represent
  in-game groups of `Actor`s.

  """
  defstruct status: :ok,
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{}
end

defimpl Rez.AST.Node, for: Rez.AST.Faction do
  import Rez.AST.NodeValidator

  alias Rez.AST.Attribute
  alias Rez.AST.NodeHelper
  alias Rez.AST.TemplateHelper

  defdelegate js_initializer(faction), to: NodeHelper

  def node_type(_faction), do: "faction"

  def js_ctor(faction) do
    NodeHelper.get_attr_value(faction, "$js_ctor", "RezEffect")
  end

  def default_attributes(_faction),
    do: %{
      "$auto_id_idx" => Attribute.number("$auto_id_idx", 0)
    }

  def pre_process(faction), do: faction

  def process(faction, %{by_id: node_map}) do
    faction
    |> NodeHelper.copy_attributes(node_map)
    |> TemplateHelper.compile_template_attributes()
  end

  def children(_faction), do: []

  def validators(_faction) do
    [
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
