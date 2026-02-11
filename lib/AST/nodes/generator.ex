defmodule Rez.AST.Generator do
  @moduledoc """
  `Rez.AST.Generator` contains the `Generator` struct that is used to represent
  run-time procedural generators.
  """
  defstruct status: :ok,
            # technically the generator itself is not a game element but
            # at runtime a RezList will be created with the same id using
            # specialised initialization code. We have a custom js_initializer
            # implementation in the AST Node module that creates the
            # appropriate initializer
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{},
            metadata: %{},
            validation: nil
end

defimpl Rez.AST.Node, for: Rez.AST.Generator do
  alias Rez.AST.NodeHelper
  alias Rez.AST.ValueEncoder

  @on_init_src ~s"""
  {
    // Lookup the object the generator is copying
    const source_id = list.getAttribute("source_id");
    const source = $(source_id);
    let copies = list.getAttribute("copies");
    if(copies instanceof RezDieRoll) {
      copies = copies.roll();
    } else if(typeof(copies) === "function") {
      copies = copies();
    }
    const customize = list.getAttribute("customize");
    const objects = [];
    for(let idx = 0; idx < copies; idx += 1) {
      const copy = source.copyWithAutoId();
      if(typeof(customize) === "function") {
        customize(copy);
      }
      objects.push(copy.id);
      game.addGameObject(copy);
    }
    list.setAttribute("values", objects);
  }
  """

  def html_processor(_generator, _attr), do: raise("@generator does not support HTML processing!")

  def node_type(_generator), do: "generator"

  def js_ctor(_generator), do: raise("@generator does not support a JS constructor!")

  def js_initializer(generator) do
    generator =
      generator
      |> NodeHelper.set_attr_value("values", {:list, []})
      |> NodeHelper.set_arrow_func_attr("on_init", {["list", "_event"], @on_init_src})

    ~s"""
    new RezList(
      "#{generator.id}",
      #{ValueEncoder.encode_attributes(generator.attributes)}
    )
    """
  end

  def process(generator, _node_map) do
    generator
  end
end
