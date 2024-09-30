defmodule Rez.Parser.ElementsParser do
  import Ergo.Combinators, only: [choice: 2]
  import Rez.Utils, only: [random_str: 0]
  import Rez.Parser.StructureParsers, only: [block: 3, block_with_id: 2, delimited_block: 3]

  def actor_element() do
    block_with_id("actor", Rez.AST.Actor)
  end

  def asset_element() do
    block_with_id("asset", Rez.AST.Asset)
  end

  def behaviour_element() do
    block_with_id("behaviour", Rez.AST.Behaviour)
  end

  def card_element() do
    block_with_id("card", Rez.AST.Card)
  end

  def effect_element() do
    block_with_id("effect", Rez.AST.Effect)
  end

  def faction_element() do
    block_with_id("faction", Rez.AST.Faction)
  end

  def filter_element() do
    block_with_id("filter", Rez.AST.Filter)
  end

  def game_element() do
    block("game", Rez.AST.Game, fn _attrs -> "game" end)
  end

  def generator_element() do
    block_with_id("generator", Rez.AST.Generator)
  end

  def group_element() do
    block_with_id("group", Rez.AST.Group)
  end

  def inventory_element() do
    block_with_id("inventory", Rez.AST.Inventory)
  end

  def item_element() do
    block_with_id("item", Rez.AST.Item)
  end

  def list_element() do
    block_with_id("list", Rez.AST.List)
  end

  def object_element() do
    block_with_id("object", Rez.AST.Object)
  end

  def patch_element() do
    block_with_id("patch", Rez.AST.Patch)
  end

  def plot_element() do
    block_with_id("plot", Rez.AST.Plot)
  end

  def scene_element() do
    block_with_id("scene", Rez.AST.Scene)
  end

  def script_element() do
    delimited_block("script", fn -> "script_" <> random_str() end, Rez.AST.Script)
  end

  def slot_element() do
    block_with_id("slot", Rez.AST.Slot)
  end

  def style_element() do
    delimited_block("stylesheet", fn -> "styles_" <> random_str() end, Rez.AST.Style)
  end

  def system_element() do
    block_with_id("system", Rez.AST.System)
  end

  def timer_element() do
    block_with_id("timer", Rez.AST.Timer)
  end

  def element() do
    choice(
      [
        actor_element(),
        asset_element(),
        behaviour_element(),
        card_element(),
        effect_element(),
        faction_element(),
        filter_element(),
        generator_element(),
        game_element(),
        group_element(),
        inventory_element(),
        item_element(),
        list_element(),
        object_element(),
        patch_element(),
        plot_element(),
        scene_element(),
        script_element(),
        slot_element(),
        style_element(),
        system_element(),
        timer_element()
      ],
      label: "element"
    )
  end
end