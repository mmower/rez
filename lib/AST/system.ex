defmodule Rez.AST.System do
  @moduledoc """
  `Rez.AST.System` represents in-game systems for custom behaviours.
  """
  alias __MODULE__
  alias Rez.AST.NodeHelper

  defstruct status: :ok,
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

  def node_type(_system), do: "system"

  def pre_process(system), do: system

  def process(system), do: system

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
      attribute_present?(
        "on_tick",
        attribute_has_type?(
          :function,
          validate_has_params?(1)
        )
      )
    ]
  end
end
