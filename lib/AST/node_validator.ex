defmodule Rez.AST.NodeValidator do
  @moduledoc """
  `Rez.AST.NodeValidator` defines the `Validation` struct and contains
  functions for validating child nodes and attribute presence/value and so on.
  """

  alias Rez.AST.Attribute
  alias Rez.AST.NodeHelper
  alias Rez.AST.Game

  def find_attribute(%Game{} = game, %{} = node, attr_key)
      when is_binary(attr_key) do
    case NodeHelper.get_attr(node, attr_key) do
      nil ->
        with parent when not is_nil(parent) <- NodeHelper.get_attr_value(node, "$parent", nil) do
          find_attribute(game, parent, attr_key)
        end

      %Attribute{} = attr ->
        attr
    end
  end

  @syntax %{
    attr_ref: ~s|&elem_id.attr_name|,
    elem_ref: ~s|#elem_id|,
    string: ~s|"string"|,
    list: ~s|[item1 item2 ...]|,
    set: ~s|\#{item1 item2 ...}|
  }

  def syntax_for_type(type) do
    Map.get(@syntax, type)
  end

  def syntax_help(types) when is_list(types) do
    help = types |> Enum.map(&syntax_for_type/1) |> Enum.reject(&is_nil/1)

    case help do
      [] ->
        ""

      list ->
        " (syntax: " <> Enum.join(list, ", ") <> ")"
    end
  end

  def syntax_help(type) do
    case syntax_for_type(type) do
      nil ->
        ""

      syntax ->
        " (syntax: " <> syntax <> ")"
    end
  end
end
