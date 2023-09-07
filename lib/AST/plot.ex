defmodule Rez.AST.Plot do
  @moduledoc """
  `Rez.AST.Plot` defines the `Plot` struct.

  A `Plot` represents an element of structured narrative within a game. Every
  `Plot` has `Stage`s that represent the players current narrative progress in
  that `Plot`.

  Each `Stage` has requirements that must be met before the player can advance
  the plot to that `Stage`.

  The game can query a `Plot` to see how far advanced it is and therefore
  present the appropriate options (e.g. different scenes, cards, dialog,
  or actions) available to the player.

  Additionally it is easier to intertwine `Plot`s by having the `Stage`s of one
  `Plot`, depend, upon the current `Stage` of another `Plot`.
  """

  defstruct status: :ok,
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{}
end

defimpl Rez.AST.Node, for: Rez.AST.Plot do
  import Rez.AST.NodeValidator

  alias Rez.AST.Attribute
  alias Rez.AST.NodeHelper
  alias Rez.AST.TemplateHelper

  defdelegate js_initializer(plot), to: NodeHelper

  def node_type(_plot), do: "plot"

  def js_ctor(plot) do
    NodeHelper.get_attr_value(plot, "js_ctor", "RezPlot")
  end

  def default_attributes(_plot),
    do: %{
      "cur_stage" => Attribute.number("cur_stage", 0)
    }

  def pre_process(plot), do: plot

  def process(plot, node_map) do
    plot
    |> NodeHelper.copy_attributes(node_map)
    |> TemplateHelper.compile_template_attributes()
  end

  def children(_plot), do: []

  def validators(_plot) do
    [
      attribute_present?(
        "priority",
        attribute_has_type?(
          :number,
          value_passes?(
            fn value -> value >= 1 and value <= 100 end,
            "Priority values must be between 1 (highest) and 100 (lowest)"
          )
        )
      ),
      attribute_if_present?(
        "tags",
        attribute_is_keyword_set?()
      ),
      attribute_present?(
        "stages",
        attribute_has_type?(:number)
      ),
      attribute_if_present?(
        "on_begin",
        attribute_has_type?(:function)
      ),
      attribute_if_present?(
        "on_tick",
        attribute_has_type?(:function)
      ),
      attribute_if_present?(
        "js_ctor",
        attribute_has_type?(:string)
      )
    ]
  end
end
