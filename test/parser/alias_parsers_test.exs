defmodule Rez.Parser.AliasParsesTest do
  use ExUnit.Case
  import Rez.Parser.AliasParsers
  alias Rez.AST.{Attribute, Object, Scene}

  def dummy_source(input, file \\ "test.rez", base_path \\ ".") do
    lines = String.split(input, ~r/\n/, trim: true)
    section = LogicalFile.Section.new(file, 1..Enum.count(lines), lines, 0)
    LogicalFile.assemble(base_path, [section])
  end

  test "parse empty alias definition" do
    input = """
    @alias standard_scene = scene # begin
    end
    """

    source = dummy_source(input)
    ctx = Ergo.parse(alias_define(), input, data: %{source: source, aliases: %{}})
    assert %{status: :ok, data: %{aliases: %{"standard_scene" => {"scene", %{}}}}} = ctx
  end

  test "parse alias definition with attributes" do
    input = """
    @alias standard_scene = scene # begin
      standard: true
      layout: \"\"\"
      {{{content}}}
      \"\"\"
      asset: #colourful_background
    end
    """

    scene_alias =
      {"scene",
       %{
         "standard" => %Attribute{name: "standard", type: :boolean, value: true},
         "layout" => %Attribute{name: "layout", type: :string, value: "{{{content}}}\n"},
         "asset" => %Attribute{name: "asset", type: :elem_ref, value: "colourful_background"}
       }}

    source = dummy_source(input)
    ctx = Ergo.parse(alias_define(), input, data: %{source: source, aliases: %{}})
    assert %{status: :ok, data: %{aliases: %{"standard_scene" => ^scene_alias}}} = ctx
  end

  test "parse alias definition and use" do
    input = """
    @standard_scene first_scene begin
      light_level: 0.1
    end
    """

    aliases = %{
      "standard_scene" =>
        {"scene",
         %{
           "standard" => %Attribute{name: "standard", type: :boolean, value: true},
           "layout" => %Attribute{name: "layout", type: :string, value: "{{{content}}}\n"},
           "asset" => %Attribute{name: "asset", type: :elem_ref, value: "colourful_background"}
         }}
    }

    source = dummy_source(input)
    ctx = Ergo.parse(alias_block(), input, data: %{source: source, aliases: aliases, id_map: %{}})

    assert %{
             status: :ok,
             ast: %Scene{
               id: "first_scene",
               attributes: %{
                 "standard" => %Attribute{name: "standard", type: :boolean, value: true},
                 "layout" => %Attribute{name: "layout", type: :string, value: "{{{content}}}\n"},
                 "asset" => %Attribute{
                   name: "asset",
                   type: :elem_ref,
                   value: "colourful_background"
                 },
                 "light_level" => %Attribute{name: "light_level", type: :number, value: 0.1}
               }
             }
           } = ctx
  end

  test "parse merges default & defined tags" do
    input = """
    @class warlord begin
      tags: \#{:combat_class}
    end
    """

    source = dummy_source(input)

    aliases = %{
      "class" =>
        {"object",
         %{
           "tags" => %Attribute{
             name: "tags",
             type: :set,
             value: MapSet.new([{:keyword, "class"}])
           }
         }}
    }

    assert %{status: :ok, ast: ast} =
             Ergo.parse(alias_block(), input,
               data: %{source: source, aliases: aliases, id_map: %{}}
             )

    assert %Object{
             id: "warlord",
             attributes: %{
               "tags" => tags_attr
             }
           } = ast

    assert %{name: "tags", type: :set, value: tags} = tags_attr
    assert MapSet.member?(tags, {:keyword, "class"})
    assert MapSet.member?(tags, {:keyword, "combat_class"})
  end
end
