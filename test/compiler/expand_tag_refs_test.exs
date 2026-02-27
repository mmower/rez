defmodule Rez.Compiler.ExpandTagRefsTest do
  use ExUnit.Case

  alias Rez.AST.NodeHelper
  alias Rez.Compiler.Compilation
  alias Rez.Compiler.Phases.ExpandTagRefs

  defp make_card(id) do
    %Rez.AST.Card{id: id, attributes: %{}}
  end

  defp make_card_with_init_after(id, init_after_values) do
    card = make_card(id)
    NodeHelper.set_list_attr(card, "$init_after", init_after_values)
  end

  defp make_card_with_alias(id, alias_name) do
    card = make_card(id)
    NodeHelper.set_string_attr(card, "$alias", alias_name)
  end

  defp get_init_after(node) do
    NodeHelper.get_attr_value(node, "$init_after", [])
  end

  defp run(content) do
    %Compilation{status: :ok, content: content, progress: []}
    |> ExpandTagRefs.run_phase()
  end

  test "passes through nodes with no $init_after" do
    card_a = make_card("card_a")
    card_b = make_card("card_b")

    result = run([card_a, card_b])

    assert :ok = result.status
    [out_a, out_b] = result.content
    assert [] = get_init_after(out_a)
    assert [] = get_init_after(out_b)
  end

  test "passes through nodes with only elem_ref in $init_after" do
    card_a = make_card("card_a")
    card_b = make_card_with_init_after("card_b", [{:elem_ref, "card_a"}])

    result = run([card_a, card_b])

    assert :ok = result.status
    [_out_a, out_b] = result.content
    assert [{:elem_ref, "card_a"}] = get_init_after(out_b)
  end

  test "expands a tag ref to matching element refs" do
    card_a = make_card("card_a")
    card_b = make_card_with_init_after("card_b", [{:elem_name, "card"}])

    result = run([card_a, card_b])

    assert :ok = result.status
    [_out_a, out_b] = result.content
    expanded = get_init_after(out_b)
    assert {:elem_ref, "card_a"} in expanded
    refute {:elem_ref, "card_b"} in expanded
  end

  test "removes self-reference when expanding tag ref" do
    card_a = make_card_with_init_after("card_a", [{:elem_name, "card"}])

    result = run([card_a])

    assert :ok = result.status
    [out_a] = result.content
    assert [] = get_init_after(out_a)
  end

  test "expands multiple tag refs" do
    card_a = make_card("card_a")
    loc_a = make_card_with_alias("loc_a", "location")
    dependent = make_card_with_init_after("dependent", [{:elem_name, "card"}, {:elem_name, "location"}])

    result = run([card_a, loc_a, dependent])

    assert :ok = result.status
    [_out_card, _out_loc, out_dep] = result.content
    expanded = get_init_after(out_dep)
    assert {:elem_ref, "card_a"} in expanded
    assert {:elem_ref, "loc_a"} in expanded
  end

  test "mixes elem_ref and elem_name in $init_after" do
    card_a = make_card("card_a")
    card_b = make_card("card_b")
    dependent = make_card_with_init_after("dependent", [{:elem_ref, "card_a"}, {:elem_name, "card"}])

    result = run([card_a, card_b, dependent])

    assert :ok = result.status
    [_a, _b, out_dep] = result.content
    expanded = get_init_after(out_dep)
    assert {:elem_ref, "card_a"} in expanded
    assert {:elem_ref, "card_b"} in expanded
    # No duplicates
    assert length(expanded) == length(Enum.uniq(expanded))
  end

  test "unknown tag name silently expands to empty" do
    card_a = make_card_with_init_after("card_a", [{:elem_name, "nonexistent"}])

    result = run([card_a])

    assert :ok = result.status
    [out_a] = result.content
    assert [] = get_init_after(out_a)
  end

  test "skips error compilations" do
    compilation = %Compilation{status: :error, content: [], progress: []}
    result = ExpandTagRefs.run_phase(compilation)
    assert result == compilation
  end

  test "@card does not match alias elements" do
    card_a = make_card("card_a")
    loc_a = make_card_with_alias("loc_a", "location")
    dependent = make_card_with_init_after("dependent", [{:elem_name, "card"}])

    result = run([card_a, loc_a, dependent])

    assert :ok = result.status
    [_a, _loc, out_dep] = result.content
    expanded = get_init_after(out_dep)
    assert {:elem_ref, "card_a"} in expanded
    refute {:elem_ref, "loc_a"} in expanded
  end
end
