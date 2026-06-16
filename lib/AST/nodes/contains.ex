defmodule Rez.AST.Contains do
  @moduledoc """
  `Rez.AST.Contains` contains the `Contains` struct.

  A `@contains` block is nested inside an `@inventory` and declares one slot
  *position*, naming the `@slot` *type* it uses (`slot_id`) and any
  position-specific `initial_contents`/`initial_enabled`.

  `Contains` is a compile-time-only construct, fully consumed by
  `Rez.Compiler.Phases.ExpandInventorySlots`. It never appears in
  `compilation.content`, has no `id_map` entry, and generates no runtime
  object — its `id` is local to its parent `@inventory`.
  """
  defstruct status: :ok,
            game_element: false,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{},
            metadata: %{},
            validation: nil
end
