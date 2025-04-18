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

  @coll_keys [
    :actors,
    :assets,
    :behaviours,
    :cards,
    :effects,
    :factions,
    :filters,
    :generators,
    :groups,
    :inventories,
    :items,
    :lists,
    :user_components,
    :objects,
    :plots,
    :relationships,
    :scenes,
    :slots,
    :systems,
    :timers
  ]

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
            defaults: %{},
            elems: %{},
            by_id: %{},
            enums: %{},
            actors: %{},
            assets: %{},
            behaviours: %{},
            behaviour_templates: %{},
            cards: %{},
            effects: %{},
            factions: %{},
            filters: %{},
            forms: %{},
            generators: %{},
            groups: %{},
            inventories: %{},
            items: %{},
            keybindings: [],
            lists: %{},
            mixins: %{},
            objects: %{},
            patches: [],
            plots: %{},
            relationships: %{},
            scenes: %{},
            scripts: [],
            slots: %{},
            styles: [],
            systems: %{},
            timers: %{},
            user_components: %{}

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

  def add_child({:defaults, elem, attributes}, %Game{defaults: defaults} = game)
      when is_binary(elem) and is_map(attributes) do
    old_defaults = Map.get(defaults, elem, %{})
    new_defaults = Map.merge(old_defaults, attributes)
    %{game | defaults: Map.put(defaults, elem, new_defaults)}
  end

  def add_child(
        {:elem, element_name, {_target_name, _mixins} = elem_def},
        %Game{elems: elems} = game
      ) do
    %{game | elems: Map.put(elems, element_name, elem_def)}
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

  def add_child({:enum, id, values}, %Game{enums: enums} = game) do
    %{game | enums: Map.put(enums, id, values)}
  end

  def add_child({:behaviour_template, id, template}, %Game{behaviour_templates: templates} = game) do
    %{game | behaviour_templates: Map.put(templates, id, template)}
  end

  def add_child({:keybinding, _, _, _} = key_binding, %Game{keybindings: bindings} = game) do
    %{game | keybindings: [key_binding | bindings]}
  end

  def add_child({:user_component, name, impl_fn}, %Game{user_components: user_components} = game) do
    %{game | user_components: Map.put(user_components, name, impl_fn)}
  end

  def add_child(%Rez.AST.Mixin{id: id} = mixin, %Game{mixins: mixins} = game) do
    %{game | mixins: Map.put(mixins, id, mixin)}
  end

  def add_child(%{} = child, %Game{} = game) do
    add_dynamic_child(game, child)
  end

  def get_aliases_and_mixins(%Game{} = game, node) do
    base_element = Node.node_type(node)
    initial_alias = NodeHelper.get_attr_value(node, "$alias")

    {chain, mixins} = build_chain(game, initial_alias, base_element)
    {List.flatten(chain), mixins}
  end

  defp build_chain(_game, nil, base_element), do: {[base_element], MapSet.new()}

  defp build_chain(%{elems: elems} = game, current_elem, base_element) do
    case Map.get(elems, current_elem) do
      {parent_element, {:mixins, mixin_list}} ->
        current_mixins = MapSet.new(mixin_list)

        case Map.get(elems, parent_element) do
          nil ->
            {[base_element, current_elem], current_mixins}

          {_next_element, _next_mixins} ->
            {parent_chain, parent_mixins} = build_chain(game, parent_element, base_element)
            {parent_chain ++ [current_elem], MapSet.union(parent_mixins, current_mixins)}
        end

      nil ->
        {[base_element, current_elem], MapSet.new()}
    end
  end

  defp add_dynamic_child(
         %Game{by_id: by_id, defaults: defaults} = game,
         %{id: child_id, attributes: attributes} = child
       ) do
    # Which content collection is this, "scenes", "cards", "items" etc…
    content_key = struct_key(child)
    content = Map.get(game, content_key)

    if is_nil(content) do
      raise "Failed to get content: #{content_key}. Did you rename the collection and not change all uses?"
    end

    {alias_chain, mixins} = get_aliases_and_mixins(game, child)

    # Walk the alias chain from the element upwards gathering defaults
    # later aliases will override attributes defined as defaults in
    # earlier aliases, all the way up to the attributes of the element
    # itself

    base_attributes =
      Enum.reduce(alias_chain, %{}, fn alias, attrs ->
        Map.merge(attrs, Map.get(defaults, alias, %{}))
      end)

    full_attributes = Map.merge(base_attributes, attributes)

    child =
      if Enum.empty?(mixins) do
        %{child | attributes: full_attributes}
      else
        %{child | attributes: full_attributes} |> NodeHelper.set_set_attr("$mixins", mixins)
      end

    # Put the content back with its new item
    game
    |> Map.put(content_key, Map.put(content, child_id, child))
    |> Map.put(:by_id, Map.put(by_id, child_id, child))
  end

  def recognises_id?(game, id) when is_atom(id) do
    recognises_id?(game, to_string(id))
  end

  def recognises_id?(%Game{by_id: id_map}, id) when is_binary(id) do
    Map.has_key?(id_map, id)
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

  def build_template(%Game{} = game) do
    NodeHelper.set_compiled_template_attr(
      game,
      "$layout_template",
      TemplateHelper.compile_template(
        "game",
        NodeHelper.get_attr_value(game, "layout"),
        fn html ->
          custom_css_class = NodeHelper.get_attr_value(game, "css_class", "")
          css_classes = add_css_class("rez-game", custom_css_class)

          ~s|<div id="game" data-game=true class="#{css_classes}">#{html}</div>|
        end
      )
    )
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
    :lists,
    :behaviours,
    :actors,
    :assets,
    :cards,
    :effects,
    :factions,
    :groups,
    :inventories,
    :items,
    :plots,
    :relationships,
    :scenes,
    :slots,
    :systems,
    :timers,
    :objects
  ]

  def js_classes_to_init() do
    @js_classes_to_init
  end

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
      Asset.is_compile_time_script?(asset) && Asset.pre_runtime?(asset)
    end)
  end

  def js_post_runtime_assets(%Game{assets: assets}) do
    assets
    |> Map.values()
    |> Enum.filter(fn %Asset{} = asset ->
      Asset.is_compile_time_script?(asset) && !Asset.pre_runtime?(asset)
    end)
  end

  def js_runtime_assets(%Game{assets: assets}) do
    assets
    |> Map.values()
    |> Enum.filter(fn %Asset{} = asset ->
      !NodeHelper.is_template?(asset) && NodeHelper.get_attr_value(asset, "$js_runtime", false)
    end)
  end

  def style_assets(%Game{assets: assets}) do
    assets
    |> Map.values()
    |> Enum.filter(fn asset -> !NodeHelper.is_template?(asset) end)
    |> Enum.filter(&Asset.style_asset?/1)
  end

  defp generate_init_order(%Game{} = game) do
    game
    |> Node.children()
    |> Enum.filter(fn obj -> Map.get(obj, :game_element) end)
    |> InitOrder.initialization_order()
  end

  def set_init_order(%Game{} = game) do
    case generate_init_order(game) do
      {:ok, init_order} ->
        NodeHelper.set_list_attr(
          game,
          "$init_order",
          Enum.map(init_order, &{:string, &1})
        )

      {:error, message} ->
        %{game | status: {:error, "Cannot generate initialization order (#{message})!"}}
    end
  end

  def rebuild_id_map(%Game{} = game) do
    Enum.reduce(@coll_keys, game, fn key, game ->
      Enum.reduce(Map.get(game, key), game, fn {id, node}, %Game{by_id: id_map} = game ->
        %{game | by_id: Map.put(id_map, id, node)}
      end)
    end)
  end
end

defmodule InitOrder do
  import Rez.Debug
  alias Rez.AST.NodeHelper

  def initialization_order(objects) do
    case objects
         |> build_dependency_graph()
         |> topological_sort() do
      {:ok, order} ->
        {:ok, order}

      {:error, {:missing_dependencies, missing}} ->
        {:error, "Missing required dependencies: #{Enum.join(missing, ", ")}"}

      {:error, :circular_dependency} ->
        {:error, "Circular dependency detected"}
    end
  end

  def build_dependency_graph(objs) do
    graph =
      objs
      |> Enum.filter(fn obj -> Map.has_key?(obj, :id) end)
      |> Enum.map(fn obj ->
        case NodeHelper.get_attr_value(obj, "$init_after", []) do
          [] ->
            {obj.id, []}

          ancestors ->
            {obj.id,
             Enum.map(ancestors, fn {:elem_ref, ancestor_id} -> to_string(ancestor_id) end)}
        end
      end)

    # Debug the initial graph
    d_log("Initial dependency graph")

    Enum.each(graph, fn {id, deps} ->
      d_log("#{id} depends on: #{inspect(deps)}")
    end)

    graph
  end

  def topological_sort(graph) do
    # Start with an empty accumulator for sorted nodes and tracking visited nodes
    sort(graph, [], MapSet.new())
  end

  def sort([], sorted, _visited), do: {:ok, Enum.reverse(sorted)}

  def sort(remaining, sorted, visited) do
    sorted_set = MapSet.new(sorted)

    case find_next_available_node(remaining, sorted_set) do
      nil ->
        if remaining != [] do
          # Find all unique dependencies
          all_deps =
            remaining
            |> Enum.flat_map(fn {_id, deps} -> deps end)
            |> MapSet.new()

          # Find missing dependencies (those not in sorted and not in remaining)
          remaining_ids = MapSet.new(Enum.map(remaining, fn {id, _deps} -> id end))

          missing_deps =
            all_deps
            |> Enum.filter(fn dep ->
              !MapSet.member?(sorted_set, dep) && !MapSet.member?(remaining_ids, dep)
            end)

          if missing_deps != [] do
            {:error, {:missing_dependencies, missing_deps}}
          else
            {:error, :circular_dependency}
          end
        else
          {:ok, Enum.reverse(sorted)}
        end

      {object, parents} ->
        remaining = List.delete(remaining, {object, parents})
        sort(remaining, [object | sorted], MapSet.put(visited, object))
    end
  end

  # Helper function to find the next node we can process
  defp find_next_available_node(remaining, sorted_set) do
    Enum.find(remaining, fn {_object, parents} ->
      Enum.all?(parents, &MapSet.member?(sorted_set, &1))
    end)
  end
end

defimpl Rez.AST.Node, for: Rez.AST.Game do
  import Rez.AST.NodeValidator

  alias Rez.Utils

  alias Rez.AST.Attribute
  alias Rez.AST.NodeHelper
  alias Rez.AST.TemplateHelper

  alias Rez.AST.Game
  alias Rez.AST.Item

  defdelegate js_initializer(game), to: NodeHelper

  def node_type(_game), do: "game"

  def js_ctor(game) do
    NodeHelper.get_attr_value(game, "$js_ctor", "RezGame")
  end

  def default_attributes(_game) do
    %{
      "current_scene_id" => Attribute.string("current_scene_id", ""),
      "$scene_stack" => Attribute.list("$scene_stack", []),
      "$flash_messages" => Attribute.list("$flash_messages", []),
      "layout" => Attribute.source_template("layout", "${content}"),
      "$start_events" => Attribute.table("$start_events", %{})
    }
  end

  def pre_process(game), do: game

  def process(%Game{} = game, %{} = resources) do
    game
    |> Game.set_defaults()
    |> Game.build_template()
    |> TemplateHelper.compile_template_attributes()
    |> NodeHelper.process_collection(:actors, resources)
    |> NodeHelper.process_collection(:assets, resources)
    |> NodeHelper.process_collection(:behaviours, resources)
    |> NodeHelper.process_collection(:cards, resources)
    |> NodeHelper.process_collection(:effects, resources)
    |> NodeHelper.process_collection(:factions, resources)
    |> NodeHelper.process_collection(:filters, resources)
    |> NodeHelper.process_collection(:generators, resources)
    |> NodeHelper.process_collection(:groups, resources)
    |> NodeHelper.process_collection(:inventories, resources)
    |> NodeHelper.process_collection(:slots, resources)
    |> NodeHelper.process_collection(:items, resources)
    |> process_item_types()
    |> NodeHelper.process_collection(:lists, resources)
    |> NodeHelper.process_collection(:objects, resources)
    |> NodeHelper.process_collection(:plots, resources)
    |> NodeHelper.process_collection(:relationships, resources)
    |> NodeHelper.process_collection(:scenes, resources)
    |> NodeHelper.process_collection(:systems, resources)
    |> NodeHelper.process_collection(:timers, resources)
    |> Game.rebuild_id_map()
    |> Game.set_init_order()
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
    |> Utils.append_list(Map.values(game.behaviours))
    |> Utils.append_list(Map.values(game.cards))
    |> Utils.append_list(Map.values(game.effects))
    |> Utils.append_list(Map.values(game.factions))
    |> Utils.append_list(Map.values(game.filters))
    |> Utils.append_list(Map.values(game.generators))
    |> Utils.append_list(Map.values(game.groups))
    |> Utils.append_list(Map.values(game.inventories))
    # We put slot before item since there is a dependency on accepts:
    |> Utils.append_list(Map.values(game.slots))
    |> Utils.append_list(Map.values(game.items))
    |> Utils.append_list(Map.values(game.lists))
    |> Utils.append_list(Map.values(game.mixins))
    |> Utils.append_list(Map.values(game.objects))
    |> Utils.append_list(Map.values(game.plots))
    |> Utils.append_list(Map.values(game.relationships))
    |> Utils.append_list(Map.values(game.scenes))
    |> Utils.append_list(Map.values(game.systems))
    |> Utils.append_list(Map.values(game.timers))
    |> Utils.append_list(game.patches)
    |> Utils.append_list(game.scripts)
    |> Utils.append_list(game.styles)
  end

  @content_expr ~s|${content}|

  def validators(_game) do
    [
      attribute_if_present?(
        "tags",
        attribute_is_keyword_set?()
      ),
      attribute_if_present?(
        "$js_ctor",
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
          :source_template,
          validate_value_contains?(
            @content_expr,
            "Game layout attribute is expected to include a ${content} expression!"
          )
        )
      ),
      attribute_if_present?(
        "$start_events",
        attribute_has_type?(:table)
      ),
      attribute_present?(
        "initial_scene_id",
        attribute_has_type?(
          :elem_ref,
          attribute_refers_to?("scene")
        )
      ),
      attribute_if_present?(
        "bindings",
        attribute_has_type?(
          :list,
          attribute_coll_of?(:list_binding)
        )
      ),
      attribute_if_present?(
        "blocks",
        attribute_has_type?(
          :list,
          attribute_coll_of?(
            :elem_ref,
            attribute_list_references?("card")
          )
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
