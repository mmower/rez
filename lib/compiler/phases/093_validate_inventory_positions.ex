defmodule Rez.Compiler.Phases.ValidateInventoryPositions do
  @moduledoc """
  Implements the validate inventory positions phase of the Rez compiler.

  An `@inventory` declares its positions via nested `@contains` blocks, each
  naming the `@slot` *type* it uses:

      @slot engine_slot {
        accepts: :engine
        has_capacity: true
        capacity: 1
      }

      @inventory ship_inv {
        @contains left_engine {
          slot_id: #engine_slot
          contents: [#fast_engine]
        }
        @contains right_engine {
          slot_id: #engine_slot
          enabled: false
        }
      }

  The parser leaves the `@contains` blocks (`Rez.AST.Contains` structs) in the
  inventory's `metadata["nested_contains"]`. This phase checks the structural
  rules that a schema cannot express:

  - an inventory has at least one `@contains` position
  - position ids are unique within their inventory
  - a `@contains` block only uses the attributes `slot_id`, `contents`, and
    `enabled`
  - `positions` is derived and may not be authored on the inventory
  - an item is placed in at most one position across all inventories

  It also tags each `Contains` with an `alias_chain` so that
  `Rez.Compiler.Phases.ApplySchema` can validate it against `@schema contains`.
  `Rez.AST.Inventory.process/2` later turns the positions into the inventory's
  `positions` attribute.
  """

  alias Rez.Compiler.Compilation
  alias Rez.AST.{Attribute, Contains, Inventory, NodeHelper}

  @allowed_attributes ~w(slot_id contents enabled)

  def run_phase(%Compilation{status: :ok, content: content} = compilation) do
    {content, errors} =
      Enum.map_reduce(content, [], fn
        %Inventory{} = inventory, errors ->
          {tag_positions(inventory), errors ++ inventory_errors(inventory)}

        node, errors ->
          {node, errors}
      end)

    errors = errors ++ placement_errors(content)

    compilation = %{
      compilation
      | content: content,
        progress: ["Validated inventory positions" | compilation.progress]
    }

    Enum.reduce(errors, compilation, &Compilation.add_error(&2, &1))
  end

  def run_phase(compilation), do: compilation

  defp positions(%Inventory{} = inventory) do
    NodeHelper.get_meta(inventory, "nested_contains", [])
  end

  defp tag_positions(%Inventory{} = inventory) do
    tagged =
      inventory
      |> positions()
      |> Enum.map(&NodeHelper.set_meta(&1, "alias_chain", ["contains"]))

    NodeHelper.set_meta(inventory, "nested_contains", tagged)
  end

  defp inventory_errors(%Inventory{id: inv_id} = inventory) do
    positions = positions(inventory)

    [
      legacy_slots_error(inventory, inv_id),
      authored_positions_error(inventory, inv_id),
      no_positions_error(positions, inv_id),
      duplicate_ids_error(positions, inv_id)
      | Enum.flat_map(positions, fn pos ->
          [private_id_error(pos, inv_id), unknown_attributes_error(pos, inv_id)]
        end)
    ]
    |> Enum.reject(&is_nil/1)
  end

  # Table keys beginning with `_` are treated as internal and not written to
  # the runtime, so a position with such a name would silently disappear.
  defp private_id_error(%Contains{id: "_" <> _ = pos_id}, inv_id),
    do: "@inventory #{inv_id}: @contains #{pos_id}: position names may not begin with _"

  defp private_id_error(_pos, _inv_id), do: nil

  defp legacy_slots_error(inventory, inv_id) do
    if NodeHelper.has_attr?(inventory, "slots") do
      "@inventory #{inv_id}: slots: is no longer supported, declare each position with a @contains block instead"
    end
  end

  # ExpandInlineElements has already turned an authored table into a
  # `positions_id` reference by the time this phase runs, so check for both.
  defp authored_positions_error(inventory, inv_id) do
    if NodeHelper.has_attr?(inventory, "positions") or
         NodeHelper.has_attr?(inventory, "positions_id") do
      "@inventory #{inv_id}: positions is derived from @contains blocks and must not be set directly"
    end
  end

  defp no_positions_error([], inv_id),
    do: "@inventory #{inv_id}: must declare at least one @contains position"

  defp no_positions_error(_positions, _inv_id), do: nil

  defp duplicate_ids_error(positions, inv_id) do
    case positions
         |> Enum.frequencies_by(& &1.id)
         |> Enum.filter(fn {_id, count} -> count > 1 end)
         |> Enum.map(&elem(&1, 0)) do
      [] -> nil
      dups -> "@inventory #{inv_id}: duplicate @contains id(s): #{Enum.join(dups, ", ")}"
    end
  end

  defp unknown_attributes_error(%Contains{id: pos_id, attributes: attrs}, inv_id) do
    case attrs |> Map.keys() |> Enum.reject(&(&1 in @allowed_attributes)) |> Enum.sort() do
      [] ->
        nil

      unknown ->
        "@inventory #{inv_id}: @contains #{pos_id}: unknown attribute(s) #{Enum.join(unknown, ", ")} " <>
          "(allowed: #{Enum.join(@allowed_attributes, ", ")})"
    end
  end

  # An item may only be in one place at a time, so it may only be placed in
  # one position when the game starts.
  defp placement_errors(content) do
    content
    |> Enum.filter(&is_struct(&1, Inventory))
    |> Enum.flat_map(fn %Inventory{id: inv_id} = inventory ->
      inventory
      |> positions()
      |> Enum.flat_map(fn %Contains{id: pos_id} = pos ->
        pos |> item_refs() |> Enum.map(&{&1, "#{inv_id}/#{pos_id}"})
      end)
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.filter(fn {_item_id, places} -> length(places) > 1 end)
    |> Enum.sort()
    |> Enum.map(fn {item_id, places} ->
      "Item #{item_id} is placed in more than one inventory position: #{Enum.join(places, ", ")}"
    end)
  end

  defp item_refs(%Contains{attributes: %{"contents" => %Attribute{type: :list, value: items}}}) do
    for {:elem_ref, item_id} <- items, do: item_id
  end

  defp item_refs(_pos), do: []
end
