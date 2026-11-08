defmodule Rez.AST.Contains do
  @moduledoc """
  `Rez.AST.Contains` contains the `Contains` struct.

  A `@contains` block is nested inside an `@inventory` and declares one
  *position* in it. The block's id is the position's name, `slot_id` names the
  `@slot` *type* the position uses, and `contents`/`enabled` give the
  position's state when the game starts.

  `Contains` is a compile-time-only construct. It lives in its inventory's
  `metadata["nested_contains"]`, is validated by
  `Rez.Compiler.Phases.ValidateInventoryPositions` and against
  `@schema contains`, and is turned into the inventory's `positions` attribute
  by `Rez.AST.Inventory.process/2`. It never appears in `compilation.content`,
  has no `id_map` entry, and generates no runtime object — its `id` is local to
  its parent `@inventory`.
  """
  defstruct status: :ok,
            game_element: false,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{},
            metadata: %{},
            validation: nil
end

defimpl Rez.AST.Node, for: Rez.AST.Contains do
  def node_type(_contains), do: "contains"

  def process(contains, _resources), do: contains

  def js_ctor(_contains) do
    raise "@contains does not generate a runtime object"
  end

  def js_initializer(_contains) do
    raise "@contains does not generate a runtime object"
  end

  def html_processor(_contains, _attr) do
    raise "@contains does not generate a runtime object"
  end
end
