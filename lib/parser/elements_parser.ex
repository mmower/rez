defmodule Rez.Parser.ElementsParser do
  @moduledoc """
  Defines the parsers that parse the built-in elements such as @card, @game,
  @scene and so on.
  """
  import Ergo.Combinators, only: [choice: 2]

  import Rez.Utils, only: [file_name_to_js_identifier: 1]
  import Rez.Parser.StructureParsers, only: [block: 3, block_with_id: 2]
  import Rez.Parser.RelationshipParsers, only: [relationship_elem: 0]
  import Rez.Parser.ParserCache, only: [cached_parser: 1]

  def actor_element() do
    cached_parser(block_with_id("actor", Rez.AST.Actor))
  end

  def asset_element() do
    cached_parser(block_with_id("asset", Rez.AST.Asset))
  end

  def auto_asset_element() do
    cached_parser(
      block("asset", Rez.AST.Asset, fn attrs ->
        %{value: file_name} = Map.get(attrs, "file_name")
        ("asset_" <> file_name) |> Path.basename() |> file_name_to_js_identifier()
      end)
    )
  end

  def behaviour_element() do
    cached_parser(block_with_id("behaviour", Rez.AST.Behaviour))
  end

  def card_element() do
    cached_parser(block_with_id("card", Rez.AST.Card))
  end

  def effect_element() do
    cached_parser(block_with_id("effect", Rez.AST.Effect))
  end

  def faction_element() do
    cached_parser(block_with_id("faction", Rez.AST.Faction))
  end

  def filter_element() do
    cached_parser(block_with_id("filter", Rez.AST.Filter))
  end

  def game_element() do
    cached_parser(block("game", Rez.AST.Game, "game"))
  end

  def generator_element() do
    cached_parser(block_with_id("generator", Rez.AST.Generator))
  end

  def group_element() do
    cached_parser(block_with_id("group", Rez.AST.Group))
  end

  def inventory_element() do
    cached_parser(block_with_id("inventory", Rez.AST.Inventory))
  end

  def list_element() do
    cached_parser(block_with_id("list", Rez.AST.List))
  end

  def mixin_element() do
    cached_parser(block_with_id("mixin", Rez.AST.Mixin))
  end

  def object_element() do
    cached_parser(block_with_id("object", Rez.AST.Object))
  end

  def plot_element() do
    cached_parser(block_with_id("plot", Rez.AST.Plot))
  end

  def scene_element() do
    cached_parser(block_with_id("scene", Rez.AST.Scene))
  end

  def slot_element() do
    cached_parser(block_with_id("slot", Rez.AST.Slot))
  end

  def system_element() do
    cached_parser(block_with_id("system", Rez.AST.System))
  end

  def timer_element() do
    cached_parser(block_with_id("timer", Rez.AST.Timer))
  end

  def element() do
    cached_parser(
      choice(
        [
          card_element(),
          actor_element(),
          asset_element(),
          auto_asset_element(),
          behaviour_element(),
          effect_element(),
          faction_element(),
          filter_element(),
          generator_element(),
          group_element(),
          inventory_element(),
          list_element(),
          mixin_element(),
          object_element(),
          plot_element(),
          relationship_elem(),
          scene_element(),
          slot_element(),
          system_element(),
          timer_element(),
          game_element()
        ],
        label: "element"
      )
    )
  end
end
