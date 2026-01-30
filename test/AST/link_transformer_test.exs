defmodule Rez.AST.LinkTransformerTest do
  use ExUnit.Case
  doctest Rez.AST.LinkTransformer
  alias Rez.AST.LinkTransformer

  @test_html """
  <a href="https://www.example.com">Link</a>
  """

  test "leaves existing href alone" do
    assert @test_html
           |> LinkTransformer.transform()
           |> String.equivalent?(@test_html)
  end

  test "adds href=\"javascript:void(0)\" when there is no href attribute" do
    assert "<a>Link</a>"
           |> LinkTransformer.transform()
           |> String.equivalent?("<a href=\"javascript:void(0)\">Link</a>")
  end

  test "replaces card=\"card-id\" with data-event=\"card\" and data-target=\"card-id\"" do
    assert "<a card=\"card-id\">Link</a>"
           |> LinkTransformer.transform() ==
             "<a data-event=\"card\" data-target=\"card-id\" href=\"javascript:void(0)\">Link</a>"
  end

  test "replaces scene=\"scene-id\" with data-event=\"scene\" and data-target=\"scene-id\"" do
    assert "<a scene=\"scene-id\">Link</a>"
           |> LinkTransformer.transform() ==
             "<a data-event=\"switch\" data-target=\"scene-id\" href=\"javascript:void(0)\">Link</a>"
  end

  test "replaces interlude=\"scene-id\" with data-event=\"interlude\" and data-target=\"scene-id\"" do
    assert "<a interlude=\"scene-id\">Link</a>"
           |> LinkTransformer.transform() ==
             "<a data-event=\"interlude\" data-target=\"scene-id\" href=\"javascript:void(0)\">Link</a>"
  end

  test "replaces resume with data-event=\"resume\"" do
    assert "<a resume>Link</a>"
           |> LinkTransformer.transform() ==
             "<a data-event=\"resume\" href=\"javascript:void(0)\">Link</a>"
  end

  test "replaces resume=\"resume\" with data-event=\"resume\"" do
    assert "<a resume=\"resume\">Link</a>"
           |> LinkTransformer.transform() ==
             "<a data-event=\"resume\" href=\"javascript:void(0)\">Link</a>"
  end

  test "replaces event=\"handler\" with data-event=\"handler\"" do
    assert "<a event=\"attack\">Link</a>"
           |> LinkTransformer.transform() ==
             "<a data-event=\"attack\" href=\"javascript:void(0)\">Link</a>"
  end

  test "does not double-transform data-event attributes" do
    assert "<button data-event=\"foo\">Click</button>"
           |> LinkTransformer.transform() ==
             "<button data-event=\"foo\">Click</button>"
  end

  test "does not transform resume inside data-event value" do
    assert "<button data-event=\"resume\">Go back</button>"
           |> LinkTransformer.transform() ==
             "<button data-event=\"resume\">Go back</button>"
  end

  test "does not transform card inside data-event value" do
    assert "<button data-event=\"card\">Click</button>"
           |> LinkTransformer.transform() ==
             "<button data-event=\"card\">Click</button>"
  end

  test "does not transform scene inside data-event value" do
    assert "<button data-event=\"switch\">Click</button>"
           |> LinkTransformer.transform() ==
             "<button data-event=\"switch\">Click</button>"
  end

  test "does not transform interlude inside data-event value" do
    assert "<button data-event=\"interlude\">Click</button>"
           |> LinkTransformer.transform() ==
             "<button data-event=\"interlude\">Click</button>"
  end

  test "does not match partial attribute names like data-card" do
    assert "<a data-card=\"foo\" href=\"#\">Link</a>"
           |> LinkTransformer.transform() ==
             "<a data-card=\"foo\" href=\"#\">Link</a>"
  end

  test "does not mess with component links" do
    assert "<.foo bar=\"baz\" />" == LinkTransformer.transform("<.foo bar=\"baz\" />")
  end

  test "does not mess with dynamic attributes like foo={bar}" do
    assert "<.foo={bar}>" == LinkTransformer.transform("<.foo={bar}>")
  end
end
