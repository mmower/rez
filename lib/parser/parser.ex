defmodule Rez.Parser.Parser do
  @moduledoc """
  `Rez.Parser.Parser` implements the main game parser and returns a `Game`
  AST node if parsing is successful.
  """

  alias Rez.Debug
  alias LogicalFile

  alias Ergo.Context
  alias Ergo.Telemetry
  import Ergo.Combinators

  import Rez.Parser.AliasParsers
  import Rez.Parser.StructureParsers
  import Rez.Parser.UtilityParsers
  import Rez.Parser.RelationshipParsers

  import Rez.Utils, only: [random_str: 0]

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

  def filter_block() do
    block_with_id("filter", Rez.AST.Filter)
  end

  def generator_block() do
    block_with_id("generator", Rez.AST.Generator)
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

  def patch_block() do
    block_with_id("patch", Rez.AST.Patch)
  end

  def plot_block() do
    block_with_id("plot", Rez.AST.Plot)
  end

  def scene_block() do
    block_with_id("scene", Rez.AST.Scene)
  end

  def script_block() do
    delimited_block("script", fn -> "script_" <> random_str() end, Rez.AST.Script)
  end

  def slot_block() do
    block_with_id("slot", Rez.AST.Slot)
  end

  def style_block() do
    delimited_block("style", fn -> "style_" <> random_str() end, Rez.AST.Style)
  end

  def system_block() do
    block_with_id("system", Rez.AST.System)
  end

  def task_block() do
    block_with_id("task", Rez.AST.Task)
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
        filter_block(),
        generator_block(),
        group_block(),
        helper_block(),
        inventory_block(),
        item_block(),
        list_block(),
        declare_define(),
        object_block(),
        patch_block(),
        plot_block(),
        relationship_define(),
        scene_block(),
        script_block(),
        slot_block(),
        style_block(),
        system_block(),
        task_block(),
        location_block(),
        # Now user defined aliases
        alias_block()
      ],
      label: "game-content",
      debug: true
    )
  end

  def game_block() do
    block_with_children(
      "game",
      fn _attrs -> "game" end,
      Rez.AST.Game,
      game_content(),
      &Rez.AST.Game.add_child/2
    )
  end

  def top_level() do
    sequence(
      [
        iows(),
        game_block(),
        iows(),
        Ergo.Terminals.eoi()
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
        if(Debug.dbg_do?(:debug)) do
          File.write!("ast.ans", Apex.Format.format(ast))
        end

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
end
