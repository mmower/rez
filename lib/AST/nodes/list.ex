defmodule Rez.AST.List do
  @moduledoc """
  `Rez.AST.List` defines the `List` struct.

  A `List` represents a list of values. For example a list of
  options for character names.
  """

  defstruct status: :ok,
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{},
            metadata: %{},
            validation: nil
end

defimpl Rez.AST.Node, for: Rez.AST.List do
  alias Rez.AST.NodeHelper

  defdelegate js_initializer(list), to: NodeHelper
  defdelegate html_processor(list, attr), to: NodeHelper

  def node_type(_list), do: "list"

  def js_ctor(list) do
    NodeHelper.get_attr_value(list, "$js_ctor", "RezList")
  end

  @doc """
  Process the list node. If the list has an `includes` attribute, add those
  list IDs to `$init_after` to ensure they initialize first. Also ensure
  a `values` attribute exists (even if empty) so the property is created.
  """
  def process(list, _resources) do
    case NodeHelper.get_attr_value(list, "includes", nil) do
      nil ->
        list

      includes when is_list(includes) ->
        # Ensure values attribute exists so the property is created at runtime
        list =
          if NodeHelper.has_attr?(list, "values") do
            list
          else
            NodeHelper.set_list_attr(list, "values", [])
          end

        existing_init_after = NodeHelper.get_attr_value(list, "$init_after", [])
        merged = Enum.uniq(existing_init_after ++ includes)
        NodeHelper.set_list_attr(list, "$init_after", merged)
    end
  end
end
