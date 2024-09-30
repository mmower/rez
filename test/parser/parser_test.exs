defmodule Rez.Parser.ParserTest do
  use ExUnit.Case
  doctest Rez.Parser.Parser

  alias Ergo
  alias Ergo.{Context, Telemetry}
  alias LogicalFile

  alias Rez.AST.NodeHelper
  import Rez.Parser.Parser
  import Rez.Parser.ElementsParser
  import Rez.Compiler.ReadSource

  @test_script_path "test/support/test_script.rez"
  @external_resource "test/support/test_script.rez"

  setup_all do
    :erlang.system_flag(:backtrace_depth, 48)
    :ok
  end

  def dummy_source(input, file \\ "test.rez", base_path \\ ".") do
    lines = String.split(input, ~r/\n/, trim: true)
    section = LogicalFile.Section.new(file, 1..Enum.count(lines), lines, 0)
    LogicalFile.assemble(base_path, [section])
  end

  test "parse script" do
    input = read_source(@test_script_path)
    full_path = Path.expand(@test_script_path)

    assert {:ok, [%Rez.AST.Game{} = game | rest], %{} = _id_map} = parse(input)
    assert %Rez.AST.Game{position: position} = game
    assert {^full_path, 1, 1} = position
    {_file, line, _col} = position
    assert {^full_path, 1} = LogicalFile.resolve_line(input, line)

    # Tests items have been pulled in from the included file
    items = Enum.filter(rest, &is_struct(&1, Rez.AST.Item))
    assert Enum.count(items) == 4

    assert [%Rez.AST.Item{attributes: attributes}] =
             Enum.filter(items, &(NodeHelper.get_attr_value(&1, "name") == "Orcrist"))

    assert %Rez.AST.Attribute{name: "_parents", type: :list, value: [{:keyword, :sword}]} =
             Map.get(attributes, "_parents")
  end

  test "parses script element" do
    input = """
    @script {
      // Javascript code goes here
    }
    """

    %Context{status: status, ast: ast} =
      Ergo.parse(script_element(), input, data: %{id_map: %{}, source: dummy_source(input)})

    assert :ok = status

    content = NodeHelper.get_attr_value(ast, "$content") |> String.trim()

    assert ^content = "// Javascript code goes here"
  end

  test "parses style element" do
    input = """
    @stylesheet {
      # CSS styles go here
    }
    """

    %Context{status: status, ast: ast} =
      Ergo.parse(style_element(), input, data: %{id_map: %{}, source: dummy_source(input)})

    assert :ok = status

    content = NodeHelper.get_attr_value(ast, "$content") |> String.trim()

    assert ^content = "# CSS styles go here"
  end

  test "parses actor element" do
    input = """
    @actor gandalf {
      name: "Gandalf"
      alt_name: "Mithrandir"
    }
    """

    context =
      Ergo.parse(actor_element(), input, data: %{source: dummy_source(input), id_map: %{}})

    assert %{status: :ok} = context

    assert %Rez.AST.Actor{
             id: "gandalf",
             attributes: %{
               "name" => %Rez.AST.Attribute{name: "name", type: :string, value: "Gandalf"},
               "alt_name" => %Rez.AST.Attribute{
                 name: "alt_name",
                 type: :string,
                 value: "Mithrandir"
               }
             }
           } = context.ast
  end

  test "parses scene element" do
    input = """
    @scene a1s1 {
      title: "Act 1 - Scene 1"
      initial_card: #frob_card
    }
    """

    context =
      Ergo.parse(scene_element(), input, data: %{source: dummy_source(input), id_map: %{}})

    assert %{status: :ok} = context

    assert %Rez.AST.Scene{
             id: "a1s1",
             attributes: %{
               "title" => %Rez.AST.Attribute{
                 name: "title",
                 type: :string,
                 value: "Act 1 - Scene 1"
               }
             }
           } = context.ast
  end

  test "parses card element" do
    input = """
    @card first_card {
      template: "This is some **Markdown** content for this card."
    }
    """

    context = Ergo.parse(card_element(), input, data: %{source: dummy_source(input), id_map: %{}})

    assert %{status: :ok} = context

    assert %Rez.AST.Card{
             id: "first_card",
             attributes: %{
               "template" => %Rez.AST.Attribute{
                 name: "template",
                 type: :string,
                 value: "This is some **Markdown** content for this card."
               }
             }
           } = context.ast
  end

  test "parses slots" do
    input = """
    @slot main_hand_slot {
      name: "Main Hand"
      type: :1h_weapon
    }
    """

    Telemetry.start()

    assert %{status: :ok, ast: %Rez.AST.Slot{id: "main_hand_slot"}} =
             Ergo.parse(slot_element(), input, data: %{source: dummy_source(input), id_map: %{}})
  end

  test "parses inventory element" do
    input = """
    @inventory inv_1 {
      tags: #\{:shopping}
      owner: #player
      slots: #\{#main_hand_slot #off_hand_slot #two_handed_slot}
    }
    """

    Telemetry.start()

    context =
      Ergo.parse(inventory_element(), input,
        id: "inventory-1-run",
        data: %{source: dummy_source(input), id_map: %{}}
      )

    if context.status != :ok do
      events = Telemetry.get_events(context.id)
      opml = Ergo.Outline.OPML.generate_opml(context.id, events)

      case File.write("inv-run.opml", opml) do
        :ok -> true
        {:error, reason} -> IO.puts("Error: #{inspect(reason)}")
      end
    end

    assert %{status: :ok} = context

    tags = MapSet.new([{:keyword, "shopping"}])

    slots =
      MapSet.new([
        {:elem_ref, "main_hand_slot"},
        {:elem_ref, "off_hand_slot"},
        {:elem_ref, "two_handed_slot"}
      ])

    assert %Rez.AST.Inventory{
             id: "inv_1",
             attributes: %{
               "tags" => %Rez.AST.Attribute{
                 name: "tags",
                 type: :set,
                 value: ^tags
               },
               "slots" => %Rez.AST.Attribute{
                 name: "slots",
                 type: :set,
                 value: ^slots
               },
               "owner" => %Rez.AST.Attribute{
                 name: "owner",
                 type: :elem_ref,
                 value: "player"
               }
             }
           } = context.ast
  end

  test "parses item element" do
    input = """
    @item blue_cloak {
      type: :equipment
      color: "blue"
      tags: #\{:wearable :cloak}
    }
    """

    context = Ergo.parse(item_element(), input, data: %{source: dummy_source(input), id_map: %{}})

    assert %{status: :ok} = context

    tags = MapSet.new(keyword: "cloak", keyword: "wearable")

    assert %Rez.AST.Item{
             id: "blue_cloak",
             attributes: %{
               "type" => %Rez.AST.Attribute{
                 name: "type",
                 type: :keyword,
                 value: "equipment"
               },
               "color" => %Rez.AST.Attribute{
                 name: "color",
                 type: :string,
                 value: "blue"
               },
               "tags" => %Rez.AST.Attribute{
                 name: "tags",
                 type: :set,
                 value: ^tags
               }
             }
           } = context.ast
  end

  test "parses template" do
    source = ~s|```The players name is ${player.name}```|

    assert %{
             status: :ok,
             ast: {:source_template, "The players name is ${player.name}"}
           } = Ergo.parse(Rez.Parser.ValueParsers.value(), source)
  end
end
