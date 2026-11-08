defmodule Rez.SchemaDescriberTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  alias Rez.SchemaDescriber

  setup_all do
    {:ok, spec} = SchemaDescriber.load(nil)
    %{stdlib: spec}
  end

  defp row(text, attr) do
    text
    |> String.split("\n")
    |> Enum.find(&String.match?(&1, ~r/^\s+#{Regex.escape(attr)}\s/))
  end

  test "lists stdlib elements and aliases", %{stdlib: spec} do
    listing = SchemaDescriber.list_elements(spec)
    assert listing =~ "@card"
    assert listing =~ "@scene"
    assert listing =~ "@item = object"
  end

  test "describes required attributes, kinds and defaults", %{stdlib: spec} do
    assert {:ok, text} = SchemaDescriber.describe(spec, "@card")
    assert row(text, "content") =~ ~r/source_template\s+required/
    assert row(text, "faces") =~ ~r/set<keyword>\s+default \#\{:back :content\}/
    assert row(text, "blocks") =~ "ref_elem: @card"
  end

  test "resolves aliases through to the base element", %{stdlib: spec} do
    assert SchemaDescriber.alias_chain(spec, "item") == ["item", "object"]
    assert {:ok, text} = SchemaDescriber.describe(spec, "item")
    assert text =~ "@item  (item -> object)"
    assert row(text, "type") =~ "is_a: @slot/accepts"
    assert row(text, "tags") =~ "set<keyword>"
  end

  test "renders rules using @schema syntax", %{stdlib: spec} do
    assert {:ok, text} = SchemaDescriber.describe(spec, "scene")
    assert row(text, "layout_mode") =~ "in: single|stack"

    assert {:ok, text} = SchemaDescriber.describe(spec, "item")
    assert row(text, "size") =~ "min: 0"
  end

  test "reports elements without a schema", %{stdlib: spec} do
    assert {:error, reason} = SchemaDescriber.describe(spec, "nope")
    assert reason =~ "No schema found for @nope"
  end

  test "describes game-defined elements" do
    source = """
    @elem weapon = object

    @schema weapon {
      damage: {kind: :number, required: true, min: 1}
    }

    @defaults weapon {
      damage: 2
    }
    """

    assert {:ok, spec} = SchemaDescriber.load_string(source)
    assert {:ok, text} = SchemaDescriber.describe(spec, "weapon")
    assert row(text, "damage") =~ ~r/number\s+required, default 2, min: 1/
  end

  test "run prints a description and returns :ok" do
    output = capture_io(fn -> assert :ok = SchemaDescriber.run(["card"]) end)
    assert output =~ "@card"
  end

  test "run returns :error for an unknown element" do
    output = capture_io(fn -> assert :error = SchemaDescriber.run(["nope"]) end)
    assert output =~ "No schema found"
  end
end
