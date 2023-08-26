defmodule Rez.Parser.ParserTest do
  use ExUnit.Case
  doctest Rez.Parser.Parser

  alias Ergo
  alias Ergo.{Context, Telemetry}
  alias LogicalFile

  alias Rez.AST.NodeHelper
  import Rez.Parser.Parser
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

    assert {:ok, %Rez.AST.Game{} = game, %{} = _id_map} = parse(input)
    assert %Rez.AST.Game{position: position} = game
    assert {^full_path, 1, 1} = position
    {_file, line, _col} = position
    assert {^full_path, 1} = LogicalFile.resolve_line(input, line)

    # Tests an item gets pulled in from the included file
    %{items: items} = game
    assert %Rez.AST.Item{attributes: attributes} = Map.get(items, "orcrist")

    assert %Rez.AST.Attribute{name: "$parents", type: :list, value: [{:keyword, :sword}]} =
             Map.get(attributes, "$parents")
  end

  test "parses script block" do
    input = """
    @script begin
      // Javascript code goes here
    end
    """

    %Context{status: status, ast: ast} =
      Ergo.parse(script_block(), input, data: %{id_map: %{}, source: dummy_source(input)})

    assert :ok = status

    content = NodeHelper.get_attr_value(ast, "$content") |> String.trim()

    assert ^content = "// Javascript code goes here"
  end

  test "parses style block" do
    input = """
    @style begin
      # CSS styles go here
    end
    """

    %Context{status: status, ast: ast} =
      Ergo.parse(style_block(), input, data: %{id_map: %{}, source: dummy_source(input)})

    assert :ok = status

    content = NodeHelper.get_attr_value(ast, "$content") |> String.trim()

    assert ^content = "# CSS styles go here"
  end

  test "parses actor block" do
    input = """
    @actor gandalf begin
      name: "Gandalf"
      alt_name: "Mithrandir"
    end
    """

    context = Ergo.parse(actor_block(), input, data: %{source: dummy_source(input), id_map: %{}})

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

  test "parses scene block" do
    input = """
    @scene a1s1 begin
      title: "Act 1 - Scene 1"
      initial_card: #frob_card
    end
    """

    context = Ergo.parse(scene_block(), input, data: %{source: dummy_source(input), id_map: %{}})

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

  test "parses location block" do
    input = """
    @location loc_1 begin
      name: "The last homely house"
      description: \"\"\"
      Elrond's refuge at Rivendell
      \"\"\"
    end
    """

    %{status: status, ast: ast} =
      Ergo.parse(location_block(), input,
        data: %{source: dummy_source(input), aliases: %{}, id_map: %{}}
      )

    assert :ok = status

    assert %Rez.AST.Location{
             id: "loc_1",
             attributes: %{
               "name" => %Rez.AST.Attribute{
                 name: "name",
                 type: :string,
                 value: "The last homely house"
               },
               "description" => %Rez.AST.Attribute{
                 name: "description",
                 type: :string,
                 value: "Elrond's refuge at Rivendell\n"
               }
             }
           } = ast
  end

  test "parses card block" do
    input = """
    @card first_card begin
      template: "This is some **Markdown** content for this card."
    end
    """

    context = Ergo.parse(card_block(), input, data: %{source: dummy_source(input), id_map: %{}})

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
    @slot main_hand_slot begin
      name: "Main Hand"
      type: :1h_weapon
    end
    """

    Telemetry.start()

    assert %{status: :ok, ast: %Rez.AST.Slot{id: "main_hand_slot"}} =
             Ergo.parse(slot_block(), input, data: %{source: dummy_source(input), id_map: %{}})
  end

  test "parses inventory block" do
    input = """
    @inventory inv_1 begin
      tags: #\{:shopping}
      owner: #player
      slots: #\{#main_hand_slot #off_hand_slot #two_handed_slot}
    end
    """

    Telemetry.start()

    context =
      Ergo.parse(inventory_block(), input,
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

  test "parses item block" do
    input = """
    @item blue_cloak begin
      type: :equipment
      color: "blue"
      tags: #\{:wearable :cloak}
    end
    """

    context = Ergo.parse(item_block(), input, data: %{source: dummy_source(input), id_map: %{}})

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
             ast:
               {:template,
                [
                  "The players name is ",
                  {:interpolate, {:expression, {:attribute, "player", "name"}, []}}
                ]}
           } = Ergo.parse(Rez.Parser.ValueParsers.value(), source)
  end
end
