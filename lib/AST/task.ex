defmodule Rez.AST.Task do
  @moduledoc """
  `Rez.AST.Task` contains the `Task` struct and its `Node` implementation.

  A `Task` is used to represent an action or condition used in a behaviour tree.
  """

  defstruct status: :ok,
            position: {nil, 0, 0},
            id: nil,
            attributes: %{}
end

defimpl Rez.AST.Node, for: Rez.AST.Task do
  import Rez.AST.NodeValidator
  alias Rez.AST.NodeHelper

  def node_type(_task), do: "task"

  def js_ctor(task) do
    NodeHelper.get_attr_value(task, "js_ctor", "RezTask")
  end

  def default_attributes(_task), do: %{}

  def pre_process(task), do: task

  def process(task), do: task

  def children(_task), do: []

  def validators(_task) do
    [
      attribute_present?(
        "options",
        attribute_has_type?(
          :list,
          attribute_coll_of?(:keyword)
        )
      ),
      attribute_if_present?(
        "check_children",
        attribute_has_type?(:function)
      ),
      attribute_present?(
        "execute",
        attribute_has_type?(
          :function,
          validate_expects_params?(["task", "wmem"])
        )
      ),
      attribute_if_present?(
        "js_ctor",
        attribute_has_type?(:string)
      )
    ]
  end
end
