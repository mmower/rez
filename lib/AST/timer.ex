defmodule Rez.AST.Timer do
  @moduledoc """
  `Rez.AST.Timer` contains the `Timer` struct and its `Node` implementation.

  A `Timer` is used to represent an event generator that is triggered by a
  real-time delay (e.g. in 5s send this event).
  """

  defstruct status: :ok,
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{}
end

defimpl Rez.AST.Node, for: Rez.AST.Timer do
  import Rez.AST.NodeValidator

  alias Rez.AST.Attribute
  alias Rez.AST.NodeHelper
  alias Rez.AST.TemplateHelper

  defdelegate js_initializer(timer), to: NodeHelper

  def node_type(_timer), do: "timer"

  def js_ctor(timer) do
    NodeHelper.get_attr_value(timer, "$js_ctor", "RezTimer")
  end

  def default_attributes(timer),
    do: %{
      "auto_start" => Attribute.boolean("auto_start", false),
      "repeats" => Attribute.boolean("repeats", false),
      "$timer" => Attribute.string("$timer", ""),
      "event" => Attribute.keyword("event", timer.id),
      "on_game_started" =>
        Attribute.arrow_function(
          "on_game_started",
          {["timer"], ~s|{if(timer.auto_start) {timer.run();}; return {handled: true};}|}
        ),
      "on_game_loaded" =>
        Attribute.arrow_function(
          "on_game_loaded",
          {["timer"], ~s|{if(timer.auto_start) {timer.run();}; return {handled: true};}|}
        )
    }

  def pre_process(timer), do: timer

  def process(timer, _node_map) do
    timer
    |> TemplateHelper.compile_template_attributes()
  end

  def children(_timer), do: []

  def validators(_timer) do
    [
      attribute_if_present?(
        "$init_after",
        attribute_has_type?(:list, attribute_coll_of?(:elem_ref))
      ),
      attribute_present?(
        "interval",
        attribute_has_type?(
          :number,
          value_passes?(fn secs -> secs > 0 end, "greater than zero")
        )
      ),
      attribute_if_present?(
        "event",
        attribute_has_type?(:keyword)
      ),
      attribute_if_present?(
        "auto_start",
        attribute_has_type?(:boolean)
      ),
      attribute_if_present?(
        "repeats",
        attribute_has_type?(:boolean)
      ),
      attribute_if_present?(
        "count",
        attribute_has_type?(
          :number,
          value_passes?(fn times -> times > 0 end, "greater than zero")
        )
      ),
      attribute_if_present?(
        "on_game_started",
        attribute_has_type?(:function)
      ),
      attribute_if_present?(
        "on_game_loaded",
        attribute_has_type?(:function)
      ),
      attribute_if_present?(
        "$js_ctor",
        attribute_has_type?(:string)
      )
    ]
  end
end
