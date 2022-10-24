defmodule Rez.AST.NodeHelperTest do
  use ExUnit.Case
  doctest Rez.AST.NodeHelper

  alias Rez.AST.Attribute
  import Rez.AST.NodeHelper

  test "encodes string to JS" do
    encoding = encode_attribute(Attribute.string("title", "Twisty Maze Adventure"))
    assert {"title", "\"Twisty Maze Adventure\""} = encoding
  end

  test "encodes list to JS" do
    encoding = encode_attribute(Attribute.list("tags", [{:elem_ref, "foo"}, {:elem_ref, "bar"}]))
    assert {"tags", "[\"foo\", \"bar\"]"} = encoding
  end

  test "encodes function to JS" do
    encoding = encode_attribute(Attribute.function("on_start", {["game", "event"], "{return game;}"}))
    assert {"on_start", "(game, event) => {return game;}"} = encoding
  end

  test "encode attributes" do
    game =
      %Rez.AST.Game{}
      |> set_string_attr("title", "Twisty Maze Adventure")
      |> set_func_attr("on_start", {["game", "event"], "{return game;}"})
    encoding = encode_attributes(game.attributes)
    assert "{\"on_start\": (game, event) => {return game;},\n\"title\": \"Twisty Maze Adventure\"}" = encoding
  end

end
