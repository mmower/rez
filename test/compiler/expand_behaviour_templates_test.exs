defmodule Rez.Compiler.ExpandBehaviourTemplatesTest do
  use ExUnit.Case

  alias Rez.AST.NodeHelper
  alias Rez.AST.BehaviourTemplate
  alias Rez.AST.ValueEncoder
  alias Rez.Compiler.Compilation
  alias Rez.Compiler.Phases.ExpandBehaviourTemplates

  defp make_actor(id) do
    %Rez.AST.Actor{id: id, attributes: %{}}
  end

  defp set_bht(node, name, value) do
    NodeHelper.set_bht_attr(node, name, {:bht, value})
  end

  defp get_bht(node, name) do
    NodeHelper.get_attr_value(node, name)
  end

  defp run(content) do
    %Compilation{status: :ok, content: content, progress: []}
    |> ExpandBehaviourTemplates.run_phase()
  end

  test "passes through behaviour trees with no template references" do
    tree = {"$sequence", %{}, [{"cond_a", %{}, []}, {"act_b", %{}, []}]}
    actor = set_bht(make_actor("a"), "behaviours", tree)

    result = run([actor])

    assert :ok = result.status
    [out] = result.content
    assert ^tree = get_bht(out, "behaviours")
  end

  test "expands template references nested within a behaviour tree" do
    template_body = {"$sequence", %{}, [{"cond_taunted", %{}, []}]}
    template = %BehaviourTemplate{id: "behaviour_taunted", template: template_body}

    tree =
      {"$select", %{},
       [
         {:template, "behaviour_taunted"},
         {"act_advance", %{}, []}
       ]}

    actor = set_bht(make_actor("a"), "behaviours", tree)

    result = run([template, actor])

    assert :ok = result.status
    out = Enum.find(result.content, &match?(%Rez.AST.Actor{}, &1))

    assert {"$select", %{}, [^template_body, {"act_advance", %{}, []}]} =
             get_bht(out, "behaviours")
  end

  test "recursively expands templates that reference other templates" do
    inner_body = {"act_melee_attack", %{}, []}
    inner = %BehaviourTemplate{id: "behaviour_melee", template: inner_body}

    # A template whose body refers to another template
    outer_body = {"$sequence", %{}, [{:template, "behaviour_melee"}]}
    outer = %BehaviourTemplate{id: "behaviour_outer", template: outer_body}

    actor = set_bht(make_actor("a"), "behaviours", {"$select", %{}, [{:template, "behaviour_outer"}]})

    result = run([inner, outer, actor])

    assert :ok = result.status
    out = Enum.find(result.content, &match?(%Rez.AST.Actor{}, &1))
    assert {"$select", %{}, [{"$sequence", %{}, [^inner_body]}]} = get_bht(out, "behaviours")
  end

  test "expanded tree can be encoded by the value encoder" do
    template_body = {"$sequence", %{}, [{"cond_taunted", %{}, []}]}
    template = %BehaviourTemplate{id: "behaviour_taunted", template: template_body}

    tree = {"$select", %{}, [{:template, "behaviour_taunted"}, {"act_advance", %{}, []}]}
    actor = set_bht(make_actor("a"), "behaviours", tree)

    result = run([template, actor])
    out = Enum.find(result.content, &match?(%Rez.AST.Actor{}, &1))

    encoded = ValueEncoder.encode_bht(get_bht(out, "behaviours"))
    assert encoded =~ "behaviour: \"$select\""
    assert encoded =~ "behaviour: \"$sequence\""
    assert encoded =~ "behaviour: \"cond_taunted\""
  end
end
