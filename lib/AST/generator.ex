defmodule Rez.AST.Generator do
  @moduledoc """
  `Rez.AST.Generator` contains the `Generator` struct that is used to represent
  run-time procedural generators.
  """
  defstruct status: :ok,
            game_element: true, # technically not, but it resovles to a RezList of the same id
            position: {nil, 0, 0},
            id: nil,
            attributes: %{}
end

defimpl Rez.AST.Node, for: Rez.AST.Generator do
  alias Rez.AST.Attribute
  import Rez.AST.NodeValidator

  def node_type(_generator), do: "generator"

  def js_ctor(_generator) do
    raise "@generator does not support a JS constructor!"
  end

  def default_attributes(_generator),
    do: %{
      "customize" => Attribute.arrow_function("customize", {["obj"], "obj"})
    }

  def pre_process(generator), do: generator

  def process(generator), do: generator

  def children(_generator), do: []

  def validators(_generator) do
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
      attribute_present?("source", attribute_has_type?(:elem_ref, validate_is_elem?())),
      attribute_present?(
        "copies",
        attribute_has_type?(
          :number,
          value_passes?(fn n -> n >= 0 end, "cannot specify negative copies!")
        )
      ),
      attribute_if_present?("customize", attribute_has_type?(:function))
    ]
  end
end
