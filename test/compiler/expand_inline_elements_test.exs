defmodule Rez.Compiler.ExpandInlineElementsTest do
  use ExUnit.Case

  alias Rez.AST.Attribute
  alias Rez.AST.Object
  alias Rez.Compiler.Compilation
  alias Rez.Compiler.Phases.ExpandInlineElements

  defp make_compilation(content) do
    %Compilation{status: :ok, content: content}
  end

  test "passes through elements with no table attributes" do
    obj = %Object{
      id: "a",
      game_element: true,
      attributes: %{
        "name" => %Attribute{name: "name", type: :string, value: "test"}
      }
    }

    result = ExpandInlineElements.run_phase(make_compilation([obj]))

    assert :ok = result.status
    assert [^obj] = result.content
  end

  test "expands a table attribute into a sub-element with deterministic id" do
    stats_map = %{
      "str" => %Attribute{name: "str", type: :number, value: 5},
      "end" => %Attribute{name: "end", type: :number, value: 6}
    }

    obj = %Object{
      id: "a",
      game_element: true,
      attributes: %{
        "stats" => %Attribute{name: "stats", type: :table, value: stats_map}
      }
    }

    result = ExpandInlineElements.run_phase(make_compilation([obj]))

    assert :ok = result.status
    assert length(result.content) == 2

    [parent, sub] = result.content

    # Parent should have stats_id elem_ref and no stats table
    assert %Object{id: "a"} = parent
    refute Map.has_key?(parent.attributes, "stats")
    assert %Attribute{name: "stats_id", type: :elem_ref, value: sub_id} = parent.attributes["stats_id"]

    # Sub-element id should be exactly "a_stats" (deterministic, no uid suffix)
    assert sub_id == "a_stats"

    # Sub-element should have the original table's attributes
    assert %Object{id: "a_stats"} = sub
    assert %Attribute{name: "str", type: :number, value: 5} = sub.attributes["str"]
    assert %Attribute{name: "end", type: :number, value: 6} = sub.attributes["end"]
  end

  test "expands nested table attributes recursively" do
    inner_map = %{
      "x" => %Attribute{name: "x", type: :number, value: 1}
    }

    outer_map = %{
      "inner" => %Attribute{name: "inner", type: :table, value: inner_map}
    }

    obj = %Object{
      id: "root",
      game_element: true,
      attributes: %{
        "outer" => %Attribute{name: "outer", type: :table, value: outer_map}
      }
    }

    result = ExpandInlineElements.run_phase(make_compilation([obj]))

    assert :ok = result.status
    # root + outer sub-element + inner sub-element
    assert length(result.content) == 3

    [root | rest] = result.content

    assert %Object{id: "root"} = root
    refute Map.has_key?(root.attributes, "outer")
    assert %Attribute{type: :elem_ref, value: "root_outer"} = root.attributes["outer_id"]

    outer_obj = Enum.find(rest, &(&1.id == "root_outer"))
    assert outer_obj

    # The outer sub-element should also have been expanded
    refute Map.has_key?(outer_obj.attributes, "inner")
    assert %Attribute{type: :elem_ref, value: "root_outer_inner"} = outer_obj.attributes["inner_id"]
  end

  test "errors when table expansion would conflict with existing _id attribute" do
    stats_map = %{
      "str" => %Attribute{name: "str", type: :number, value: 5}
    }

    obj = %Object{
      id: "a",
      game_element: true,
      attributes: %{
        "stats" => %Attribute{name: "stats", type: :table, value: stats_map},
        "stats_id" => %Attribute{name: "stats_id", type: :elem_ref, value: "something_else"}
      }
    }

    result = ExpandInlineElements.run_phase(make_compilation([obj]))

    assert :error = result.status
    assert [error] = result.errors
    assert error =~ "stats_id"
    assert error =~ "a"
  end

  test "skips non-game elements" do
    # Const is not a game_element
    const = %Rez.AST.Const{name: "MY_CONST", value: {:number, 42}}

    result = ExpandInlineElements.run_phase(make_compilation([const]))

    assert :ok = result.status
    assert [^const] = result.content
  end

  test "expands a homogeneous list of tables into indexed sub-elements" do
    list_values = [
      {:table, %{
        "name" => %Attribute{name: "name", type: :string, value: "str"},
        "val" => %Attribute{name: "val", type: :number, value: 14}
      }},
      {:table, %{
        "name" => %Attribute{name: "name", type: :string, value: "con"},
        "val" => %Attribute{name: "val", type: :number, value: 12}
      }}
    ]

    obj = %Object{
      id: "a",
      game_element: true,
      attributes: %{
        "stats" => %Attribute{name: "stats", type: :list, value: list_values}
      }
    }

    result = ExpandInlineElements.run_phase(make_compilation([obj]))

    assert :ok = result.status
    # parent + a_stats_0 + a_stats_1
    assert length(result.content) == 3

    [parent | subs] = result.content

    assert %Object{id: "a"} = parent

    # List attribute should now contain elem_refs
    assert %Attribute{type: :list, value: refs} = parent.attributes["stats"]
    assert refs == [{:elem_ref, "a_stats_0"}, {:elem_ref, "a_stats_1"}]

    sub0 = Enum.find(subs, &(&1.id == "a_stats_0"))
    sub1 = Enum.find(subs, &(&1.id == "a_stats_1"))

    assert sub0
    assert sub1
    assert %Attribute{type: :string, value: "str"} = sub0.attributes["name"]
    assert %Attribute{type: :number, value: 14} = sub0.attributes["val"]
    assert %Attribute{type: :string, value: "con"} = sub1.attributes["name"]
    assert %Attribute{type: :number, value: 12} = sub1.attributes["val"]
  end

  test "errors on a mixed list of tables and non-table values" do
    list_values = [
      {:table, %{"x" => %Attribute{name: "x", type: :number, value: 1}}},
      {:string, "not a table"}
    ]

    obj = %Object{
      id: "a",
      game_element: true,
      attributes: %{
        "mixed" => %Attribute{name: "mixed", type: :list, value: list_values}
      }
    }

    result = ExpandInlineElements.run_phase(make_compilation([obj]))

    assert :error = result.status
    assert [error] = result.errors
    assert error =~ "mixed"
    assert error =~ "a"
    assert error =~ "mixes table"
  end

  test "passes through a list with no tables unchanged" do
    list_values = [{:string, "foo"}, {:string, "bar"}]

    obj = %Object{
      id: "a",
      game_element: true,
      attributes: %{
        "tags" => %Attribute{name: "tags", type: :list, value: list_values}
      }
    }

    result = ExpandInlineElements.run_phase(make_compilation([obj]))

    assert :ok = result.status
    assert [^obj] = result.content
  end
end
