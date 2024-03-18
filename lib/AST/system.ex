defmodule Rez.AST.System do
  @moduledoc """
  `Rez.AST.System` represents in-game systems for custom behaviours.
  """
  alias __MODULE__
  alias Rez.AST.NodeHelper

  defstruct status: :ok,
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{}

  @enabled_attr_key "enabled"

  def enabled?(%System{} = system) do
    NodeHelper.get_attr_value(system, @enabled_attr_key) == true
  end
end

defimpl Rez.AST.Node, for: Rez.AST.System do
  import Rez.AST.NodeValidator

  alias Rez.AST.NodeHelper
  alias Rez.AST.TemplateHelper

  defdelegate js_initializer(system), to: NodeHelper

  def node_type(_system), do: "system"

  def js_ctor(system) do
    NodeHelper.get_attr_value(system, "$js_ctor", "RezSystem")
  end

  def default_attributes(_system), do: %{}

  def pre_process(system), do: system

  def process(system, %{by_id: node_map}) do
    system
    |> NodeHelper.copy_attributes(node_map)
    |> TemplateHelper.compile_template_attributes()
  end

  def children(_system), do: []

  def validators(_system) do
    [
      attribute_if_present?(
        "tags",
        attribute_is_keyword_set?()
      ),
      attribute_present?(
        "enabled",
        attribute_has_type?(:boolean)
      ),
      attribute_present?(
        "priority",
        attribute_has_type?(
          :number,
          value_passes?(fn prio -> prio > 0 end, "greater than zero")
        )
      ),
      attribute_one_of_present?(["before_event", "after_event"], false),
      attribute_if_present?(
        "before_event",
        # (system, evt)
        attribute_has_type?(:function, validate_has_params?(2))
      ),
      attribute_if_present?(
        "after_event",
        # (system, evt, result)
        attribute_has_type?(:function, validate_has_params?(3))
      ),
      attribute_if_present?(
        "$js_ctor",
        attribute_has_type?(:string)
      )
    ]
  end
end
