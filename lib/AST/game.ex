defmodule Rez.AST.Game do
  @moduledoc """
  `Rez.AST.Game` contains the `Game` struct that is the root object for all
  game content.
  """
  alias __MODULE__

  alias Rez.AST.Node
  alias Rez.AST.NodeHelper
  alias Rez.AST.TemplateHelper
  alias Rez.AST.Attribute
  alias Rez.AST.Asset
  alias Rez.AST.Script
  alias Rez.AST.Style
  alias Rez.AST.Patch
  alias Rez.AST.TypeHierarchy

  import Rez.Utils

  defstruct status: :ok,
            game_element: true,
            position: {nil, 0, 0},
            id: "game",
            line: 0,
            col: 0,
            id_map: %{},
            is_a: TypeHierarchy.new(),
            init_order: [],
            attributes: %{},
            by_id: %{},
            actors: %{},
            assets: %{},
            cards: %{},
            effects: %{},
            factions: %{},
            filters: %{},
            forms: %{},
            generators: %{},
            groups: %{},
            helpers: %{},
            inventories: %{},
            locations: %{},
            items: %{},
            lists: %{},
            objects: %{},
            patches: [],
            plots: %{},
            relationships: %{},
            scenes: %{},
            scripts: [],
            slots: %{},
            styles: [],
            systems: %{},
            tasks: %{},
            zones: %{}

  def add_child(%Script{} = script, %Game{scripts: scripts} = game) do
    %{game | scripts: append_list(scripts, script)}
  end

  def add_child(%Style{} = style, %Game{styles: styles} = game) do
    %{game | styles: append_list(styles, style)}
  end

  def add_child(%Patch{} = patch, %Game{patches: patches} = game) do
    %{game | patches: append_list(patches, patch)}
  end

  def add_child(
        {:relationship, source, target, affinity},
        %Game{relationships: relationships} = game
      ) do
    %{game | relationships: Map.put(relationships, source, {target, affinity})}
  end

  def add_child(%{} = child, %Game{} = game) do
    add_dynamic_child(game, child)
  end

  #
  # We use a Map->MapSet here because a keyword might be derived from more than
  # one parent keyword, e.g.
  #
  # @derive :weapon :item
  # @derive :weapon :usable
  # => %{:weapon => #MapSet<[:item, :usable]>}
  #
  def add_child({:derive, tag, parent}, %Game{is_a: is_a} = game)
      when is_binary(tag) and is_binary(parent) do
    %{game | is_a: TypeHierarchy.add(is_a, tag, parent)}
  end

  defp add_dynamic_child(%Game{by_id: by_id} = game, %{id: child_id} = child) do
    content_key = struct_key(child)
    nodes = game |> Map.get(content_key) |> Map.put(child_id, child)

    game
    |> Map.put(content_key, nodes)
    |> Map.put(:by_id, Map.put(by_id, child_id, child))
  end

  @doc """
  ## Examples
      iex> alias Rez.AST.{Attribute, Game}
      iex> game = %Game{attributes: %{"name" => Attribute.string("name", "Test Game")}}
      iex> assert %Game{attributes: %{"title" => %Attribute{name: "title", type: :string, value: "Test Game"}}} = Game.set_default_title(game)
      iex> game = %Game{attributes: %{"name" => Attribute.string("name", "Test Game"), "title" => Attribute.string("title", "The Wondrous Test Game")}}
      iex> assert %Game{attributes: %{"title" => %Attribute{name: "title", type: :string, value: "The Wondrous Test Game"}}} = Game.set_default_title(game)
  """
  def set_default_title(%Game{attributes: %{"name" => name} = attributes} = game) do
    case Map.has_key?(attributes, "title") do
      true ->
        game

      false ->
        %{game | attributes: Map.put(attributes, "title", Attribute.string("title", name.value))}
    end
  end

  def set_defaults(%Game{} = game) do
    game
    |> set_default_title()
  end

  def process_item(%Game{} = game, key) do
    Map.put(game, key, Map.get(game, key) |> Node.process())
  end

  def process_layout(%Game{} = game) do
    case NodeHelper.get_attr_value(game, "layout") do
      nil ->
        game

      _ ->
        custom_css_class = NodeHelper.get_attr_value(game, "css_class", "")
        css_classes = add_css_class("game", custom_css_class)

        TemplateHelper.make_template(
          game,
          "layout",
          fn html ->
            ~s(<div class="#{css_classes}">) <> html <> "</div>"
          end
        )
    end
  end

  def slot_types(%Game{inventories: inventories}) do
    Enum.reduce(inventories, MapSet.new(), fn {_id, inventory}, slot_types ->
      Enum.reduce(inventory.slots, slot_types, fn {_slot_id, slot}, slot_types ->
        MapSet.put(slot_types, NodeHelper.get_attr_value(slot, "type"))
      end)
    end)
  end

  # Due to their dependency locations & zones are init'd separately
  @js_classes_to_init [
    :tasks,
    :actors,
    :assets,
    :cards,
    :effects,
    :factions,
    :groups,
    :inventories,
    :items,
    :lists,
    :plots,
    :relationships,
    :scenes,
    :slots,
    :systems,
    :objects
  ]

  def js_classes_to_init() do
    @js_classes_to_init
  end

  # def has_inventory_with_kind?(%Game{} = game, kind) do
  #   Enum.any?(game.inventories, fn {_id, inventory} ->
  #     NodeHelper.get_attr_value(inventory, "kind") == kind
  #   end)
  # end

  # Search the is_a tree for a connection between "tag" and "parent"
  def is_a(_, tag, tag), do: true

  def is_a(%{is_a: is_a}, tag, parent)
      when is_binary(tag) and is_binary(parent) and tag != parent do
    TypeHierarchy.search_is_a(is_a, tag, parent)
  end

  def expand_type(%{is_a: is_a}, tag) do
    TypeHierarchy.fan_out(is_a, tag)
  end

  def all_nodes(game) do
    [game | Node.children(game)]
  end

  def patch_list(%Game{patches: patches}) do
    patches |> Enum.sort_by(&NodeHelper.get_attr_value(&1, "class"))
  end

  def js_pre_runtime_assets(%Game{assets: assets}) do
    assets
    |> Map.values()
    |> Enum.filter(fn %Asset{} = asset ->
      !NodeHelper.is_template?(asset) && Asset.script_asset?(asset) && !Asset.js_runtime?(asset) &&
        Asset.pre_runtime?(asset)
    end)
  end

  def js_post_runtime_assets(%Game{assets: assets}) do
    assets
    |> Map.values()
    |> Enum.filter(fn %Asset{} = asset ->
      !NodeHelper.is_template?(asset) && Asset.script_asset?(asset) && !Asset.js_runtime?(asset) &&
        !Asset.pre_runtime?(asset)
    end)
  end

  def js_runtime_assets(%Game{assets: assets}) do
    assets
    |> Map.values()
    |> Enum.filter(fn %Asset{} = asset ->
      !NodeHelper.is_template?(asset) && NodeHelper.get_attr_value(asset, "js_runtime", false)
    end)
  end

  def style_assets(%Game{assets: assets}) do
    assets
    |> Map.values()
    |> Enum.filter(fn asset -> !NodeHelper.is_template?(asset) end)
    |> Enum.filter(&Asset.style_asset?/1)
  end
end

defmodule Rez.AST.Game.InitOrder do
  alias Rez.AST.NodeHelper

  def initialization_order(objects) do
    objects
    |> build_dependency_graph()
    |> topological_sort()
  end

  def build_dependency_graph(objs) do
    objs
    |> Enum.filter(fn obj -> Map.has_key?(obj, :id) end)
    |> Enum.map(fn obj ->
      parents =
        obj
        |> NodeHelper.get_attr_value("$parents", [])
        |> Enum.map(fn {:keyword, k} -> to_string(k) end)

      {obj.id, parents}
    end)
  end

  def topological_sort(graph) do
    sort(graph, [], [])
  end

  def sort([], sorted, _visited), do: {:ok, Enum.reverse(sorted)}

  def sort(remaining, sorted, visited) do
    case Enum.find(remaining, fn {_object, parents} -> Enum.all?(parents, &(&1 in sorted)) end) do
      nil ->
        {:error, :circular_dependency}

      {object, parents} ->
        remaining = List.delete(remaining, {object, parents})
        sort(remaining, [object | sorted], [object | visited])
    end
  end
end

defimpl Rez.AST.Node, for: Rez.AST.Game do
  import Rez.AST.NodeValidator
  import Rez.AST.Game.InitOrder
  alias Rez.Utils
  alias Rez.AST.{NodeHelper, ValueEncoder, Game, Item}

  def node_type(_game), do: "game"

  def js_ctor(game) do
    NodeHelper.get_attr_value(game, "js_ctor", "RezGame")
  end

  def js_initializer(game) do
    ctor = js_ctor(game)
    init_obj_ids = Enum.map_join(game.init_order, ", ", &"\"#{&1}\"")

    """
    new #{ctor}(
      [#{init_obj_ids}],
      #{ValueEncoder.encode_attributes(game.attributes)}
      );
    """
  end

  def default_attributes(_game), do: %{}

  def pre_process(game), do: game

  def process(%Game{} = game) do
    game
    |> Game.set_defaults()
    |> Game.process_layout()
    |> NodeHelper.process_collection(:actors)
    |> NodeHelper.process_collection(:assets)
    |> NodeHelper.process_collection(:tasks)
    |> NodeHelper.process_collection(:cards)
    |> NodeHelper.process_collection(:effects)
    |> NodeHelper.process_collection(:factions)
    |> NodeHelper.process_collection(:generators)
    |> NodeHelper.process_collection(:groups)
    |> NodeHelper.process_collection(:helpers)
    |> NodeHelper.process_collection(:inventories)
    |> NodeHelper.process_collection(:slots)
    |> NodeHelper.process_collection(:items)
    |> process_item_types()
    |> NodeHelper.process_collection(:lists)
    |> NodeHelper.process_collection(:objects)
    |> NodeHelper.process_collection(:plots)
    |> NodeHelper.process_collection(:relationships)
    |> NodeHelper.process_collection(:scenes)
    |> NodeHelper.process_collection(:systems)
    |> NodeHelper.process_collection(:zones)
    |> generate_init_order()
  end

  defp generate_init_order(%Game{} = game) do
    elements = game |> children |> Enum.filter(fn obj -> Map.get(obj, :game_element) end)

    case initialization_order(elements) do
      {:ok, init_order} ->
        %{game | init_order: init_order}

      {:error, :circular_dependency} ->
        %{game | status: {:error, "Cycle in parent relationship"}}
    end
  end

  # This requires the Game's type hierarchy which we have no way of passing
  # into Node.process
  def process_item_types(%Game{items: items, is_a: is_a} = game) do
    %{game | items: Utils.map_to_map(items, fn item -> Item.add_types_as_tags(item, is_a) end)}
  end

  def children(%Game{} = game) do
    []
    |> Utils.append_list(Map.values(game.actors))
    |> Utils.append_list(Map.values(game.assets))
    |> Utils.append_list(Map.values(game.tasks))
    |> Utils.append_list(Map.values(game.cards))
    |> Utils.append_list(Map.values(game.effects))
    |> Utils.append_list(Map.values(game.factions))
    |> Utils.append_list(Map.values(game.generators))
    |> Utils.append_list(Map.values(game.groups))
    |> Utils.append_list(Map.values(game.helpers))
    |> Utils.append_list(Map.values(game.inventories))
    # We put slot before item since there is a dependency on accepts:
    |> Utils.append_list(Map.values(game.slots))
    |> Utils.append_list(Map.values(game.items))
    |> Utils.append_list(Map.values(game.lists))
    |> Utils.append_list(Map.values(game.objects))
    |> Utils.append_list(Map.values(game.plots))
    |> Utils.append_list(Map.values(game.relationships))
    |> Utils.append_list(Map.values(game.scenes))
    |> Utils.append_list(Map.values(game.systems))
    |> Utils.append_list(Map.values(game.zones))
    |> Utils.append_list(game.patches)
    |> Utils.append_list(game.scripts)
    |> Utils.append_list(game.styles)
  end

  @content_expr ~r/\{\{[\{]?content[\}]?\}\}/

  def validators(_game) do
    [
      attribute_if_present?(
        "tags",
        attribute_is_keyword_set?()
      ),
      attribute_if_present?(
        "js_ctor",
        attribute_has_type?(:string)
      ),
      attribute_present?(
        "name",
        attribute_has_type?(:string)
      ),
      attribute_present?(
        "archive_format",
        attribute_has_type?(:number)
      ),
      attribute_present?(
        "layout",
        attribute_has_type?(
          :string,
          validate_value_matches?(
            @content_expr,
            "Expects layout attribute to include {{content}} or {{{content}}} expression!"
          )
        )
      ),
      attribute_present?(
        "initial_scene",
        attribute_has_type?(
          :elem_ref,
          attribute_refers_to?("scene")
        )
      ),
      attribute_present?(
        "IFID",
        attribute_has_type?(:string)
      ),
      attribute_if_present?(
        "on_init",
        attribute_has_type?(:function)
      ),
      attribute_if_present?(
        "on_start",
        attribute_has_type?(:function)
      ),
      attribute_if_present?(
        "on_save",
        attribute_has_type?(:function)
      ),
      attribute_if_present?(
        "on_load",
        attribute_has_type?(:function)
      ),
      attribute_if_present?(
        "links",
        attribute_has_type?(
          :list,
          attribute_coll_of?(:string)
        )
      ),
      attribute_if_present?(
        "scripts",
        attribute_has_type?(
          :list,
          attribute_coll_of?(:string)
        )
      )
    ]
  end
end
