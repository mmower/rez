defmodule Rez.Compiler.Phases.ExpandInventorySlots do
  @moduledoc """
  Implements the expand inventory slots phase of the Rez compiler.

  `@inventory` declares its slot positions via nested `@contains` blocks,
  each naming the `@slot` *type* it uses:

      @slot engine_slot {
        accepts: :engine
        has_capacity: true
        capacity: 1
      }

      @inventory ship_inv {
        @contains left_engine {
          slot_id: #engine_slot
          initial_contents: [#fast_engine]
        }
        @contains right_engine {
          slot_id: #engine_slot
        }
      }

  This phase consumes each `@inventory`'s `metadata["nested_contains"]` (a
  list of `Rez.AST.Contains` structs produced by the parser) and:

  - derives a `slots:` list-binding attribute, keyed by each `@contains`
    block's own id (e.g. `left_engine`), pointing at its `slot_id` — the
    exact shape `Rez.AST.Inventory.process/2` already consumes
  - hoists `initial_contents`/`initial_enabled` from each `@contains` block
    to `initial_{contains_id}` / `initial_{contains_id}_enabled` on the
    inventory

  `Rez.AST.Contains` structs are fully consumed here and never appear in
  `compilation.content`. An `@inventory` that authors `slots:` directly
  while also declaring `@contains` children is a compile error — `slots:`
  is derived, not authored.
  """

  alias Rez.Compiler.Compilation
  alias Rez.AST.{Attribute, Inventory, Contains, NodeHelper, Slot}

  def run_phase(%Compilation{status: :ok, content: content, progress: progress} = compilation) do
    case expand_all(content) do
      {:ok, expanded_content} ->
        %{
          compilation
          | content: expanded_content,
            progress: ["Expanded inventory slots" | progress]
        }

      {:error, error} ->
        Compilation.add_error(compilation, error)
    end
  end

  def run_phase(compilation), do: compilation

  defp expand_all(content) do
    {expanded, errors} =
      Enum.reduce(content, {[], []}, fn node, {nodes_acc, errors_acc} ->
        case node do
          %Inventory{metadata: %{"nested_contains" => [_ | _] = positions}} ->
            case expand_inventory(node, positions, content) do
              {:ok, updated_node} -> {nodes_acc ++ [updated_node], errors_acc}
              {:error, error} -> {nodes_acc ++ [node], [error | errors_acc]}
            end

          _ ->
            {nodes_acc ++ [node], errors_acc}
        end
      end)

    if errors == [] do
      {:ok, expanded}
    else
      {:error, Enum.join(Enum.reverse(errors), "; ")}
    end
  end

  defp expand_inventory(%Inventory{id: inv_id} = inventory, positions, content) do
    with :ok <- check_no_authored_slots(inventory, inv_id),
         :ok <- check_no_duplicate_ids(positions, inv_id) do
      build_slots(inventory, inv_id, positions, content)
    end
  end

  defp check_no_authored_slots(inventory, inv_id) do
    if NodeHelper.has_attr?(inventory, "slots") do
      {:error,
       "@inventory #{inv_id}: slots: is derived from @contains positions and must not be set directly"}
    else
      :ok
    end
  end

  defp check_no_duplicate_ids(positions, inv_id) do
    duplicates =
      positions
      |> Enum.map(& &1.id)
      |> Enum.frequencies()
      |> Enum.filter(fn {_id, count} -> count > 1 end)
      |> Enum.map(&elem(&1, 0))

    case duplicates do
      [] ->
        :ok

      dups ->
        {:error,
         "@inventory #{inv_id}: duplicate @contains id(s): #{Enum.join(dups, ", ")}"}
    end
  end

  defp build_slots(inventory, inv_id, positions, content) do
    positions
    |> Enum.reduce_while({:ok, {inventory, []}}, fn
      %Contains{id: local_id, attributes: attrs}, {:ok, {inv_acc, bindings}} ->
        with %Attribute{type: :elem_ref, value: target} <- Map.get(attrs, "slot_id"),
             true <- slot_exists?(content, target) do
          effective_id = local_id
          inv_acc = hoist_initial_attrs(inv_acc, attrs, effective_id)
          binding = {:list_binding, {effective_id, {:source, false, {:elem_ref, target}}}}
          {:cont, {:ok, {inv_acc, bindings ++ [binding]}}}
        else
          nil ->
            {:halt,
             {:error,
              "@inventory #{inv_id}: @contains #{local_id} requires a slot_id: #ref attribute"}}

          false ->
            {:halt,
             {:error,
              "@inventory #{inv_id}: @contains #{local_id}: slot_id does not refer to a @slot"}}

          _ ->
            {:halt,
             {:error, "@inventory #{inv_id}: @contains #{local_id}: slot_id must be a #ref"}}
        end
    end)
    |> case do
      {:ok, {inv_acc, bindings}} ->
        inv_acc =
          inv_acc
          |> NodeHelper.set_list_attr("slots", bindings)
          |> NodeHelper.set_meta("nested_contains", [])

        {:ok, inv_acc}

      {:error, _} = err ->
        err
    end
  end

  defp hoist_initial_attrs(inventory, attrs, effective_id) do
    Enum.reduce(attrs, inventory, fn
      {"initial_contents", attr}, inv ->
        NodeHelper.set_attr(inv, %{attr | name: "initial_#{effective_id}"})

      {"initial_enabled", attr}, inv ->
        NodeHelper.set_attr(inv, %{attr | name: "initial_#{effective_id}_enabled"})

      _, inv ->
        inv
    end)
  end

  defp slot_exists?(content, target_id) do
    Enum.any?(content, &match?(%Slot{id: ^target_id}, &1))
  end
end
