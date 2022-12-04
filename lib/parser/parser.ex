defmodule Rez.Parser.Parser do
  @moduledoc """
  `Rez.Parser.Parser` implements the main game parser and returns a `Game`
  AST node if parsing is successful.
  """

  alias LogicalFile

  alias Ergo.Context
  alias Ergo.Telemetry
  import Ergo.Combinators

  import Rez.Parser.AliasParsers
  import Rez.Parser.StructureParsers
  import Rez.Parser.UtilityParsers

  def actor_block() do
    block_with_id("actor", Rez.AST.Actor)
  end

  def asset_block() do
    block_with_id("asset", Rez.AST.Asset)
  end

  def card_block() do
    block_with_id("card", Rez.AST.Card)
  end

  def effect_block() do
    block_with_id("effect", Rez.AST.Effect)
  end

  def faction_block() do
    block_with_id("faction", Rez.AST.Faction)
  end

  def group_block() do
    block_with_id("group", Rez.AST.Group)
  end

  def helper_block() do
    block_with_id("helper", Rez.AST.Helper)
  end

  def inventory_block() do
    block_with_id("inventory", Rez.AST.Inventory)
  end

  def item_block() do
    block_with_id("item", Rez.AST.Item)
  end

  def list_block() do
    block_with_id("list", Rez.AST.List)
  end

  def location_block() do
    block_with_id("location", Rez.AST.Location)
  end

  def object_block() do
    block_with_id("object", Rez.AST.Object)
  end

  def plot_block() do
    block_with_id("plot", Rez.AST.Plot)
  end

  def relationship_block() do
    block("rel", Rez.AST.Relationship, fn attributes ->
      with %{type: :elem_ref, value: source} <- Map.get(attributes, "source"),
           %{type: :elem_ref, value: target} <- Map.get(attributes, "target") do
        "rel_" <> source <> "_" <> target
      else
        nil -> "rel_" <> Rez.Utils.random_str()
      end
    end)
  end

  def scene_block() do
    block_with_id("scene", Rez.AST.Scene)
  end

  def script_block() do
    delimited_block("script", Rez.AST.Script, :code)
  end

  def slot_block() do
    block_with_id("slot", Rez.AST.Slot)
  end

  def style_block() do
    delimited_block("style", Rez.AST.Style, :styles)
  end

  def system_block() do
    block_with_id("system", Rez.AST.System)
  end

  def task_block() do
    block_with_id("task", Rez.AST.Task)
  end

  def zone_block() do
    block_with_id_children("zone", Rez.AST.Zone, location_block(), &Rez.AST.Zone.add_child/2)
  end

  def game_content() do
    choice(
      [
        alias_define(),
        derive_define(),
        # Now the pre-defined blocks
        actor_block(),
        asset_block(),
        card_block(),
        effect_block(),
        faction_block(),
        group_block(),
        helper_block(),
        inventory_block(),
        item_block(),
        list_block(),
        object_block(),
        plot_block(),
        relationship_block(),
        scene_block(),
        script_block(),
        slot_block(),
        style_block(),
        system_block(),
        task_block(),
        zone_block(),
        # Now user defined aliases
        alias_block()
      ],
      label: "game-content",
      debug: true
    )
  end

  def game_block() do
    block_with_children("game", Rez.AST.Game, game_content(), &Rez.AST.Game.add_child/2)
  end

  def top_level() do
    sequence(
      [
        iows(),
        game_block()
      ],
      label: "top-level",
      ast: &List.first/1
    )
  end

  def parse(%LogicalFile{} = source, telemetry \\ false) do
    if telemetry, do: Telemetry.start()

    case Ergo.parse(top_level(), to_string(source),
           data: %{source: source, aliases: %{}, id_map: %{}}
         ) do
      %Context{status: :ok, ast: ast, data: %{id_map: id_map}} ->
        {:ok, ast, id_map}

      %Context{status: {code, reasons}, id: id, line: line, col: col, input: input}
      when code in [:error, :fatal] ->
        if telemetry,
          do:
            File.write(
              "compiler-output.opml",
              Ergo.Outline.OPML.generate_opml(id, Telemetry.get_events(id))
            )

        {:error, reasons, line, col, input}
    end
  end

  # def profile_run() do
  #   source = Source.Reader.read_source("test/support", "test_script.rez", [
  #     Source.Macros.Include.include_macro(~r/^\s*%\((?<file>.*)\)/),
  #     Source.Macros.LineComment.line_comment_macro(~r/^%%/)
  #   ])
  #   {:ok, game} = Rez.Parser.Parser.parse(source)
  #   IO.puts("Game has #{inspect(Map.keys(game))} entries")
  # end
end
