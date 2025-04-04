defmodule Rez.AST.Generator do
  @moduledoc """
  `Rez.AST.Generator` contains the `Generator` struct that is used to represent
  run-time procedural generators.
  """
  defstruct status: :ok,
            # technically not, but it resovles to a RezList of the same id
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{}
end

defimpl Rez.AST.Node, for: Rez.AST.Generator do
  import Rez.AST.NodeValidator

  alias Rez.AST.Attribute

  alias Rez.AST.TemplateHelper

  def node_type(_generator), do: "generator"

  def js_ctor(_generator), do: raise("@generator does not support a JS constructor!")

  def js_initializer(_obj), do: raise("@generator does not support a JS initializer!")

  def default_attributes(_generator),
    do: %{
      "customize" => Attribute.arrow_function("customize", {["obj"], "obj"})
    }

  def pre_process(generator), do: generator

  def process(generator, _node_map) do
    generator
    |> TemplateHelper.compile_template_attributes()
  end

  def children(_generator), do: []

  def validators(_generator) do
    [
      attribute_if_present?(
        "$init_after",
        attribute_has_type?(:list, attribute_coll_of?(:elem_ref))
      ),
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
