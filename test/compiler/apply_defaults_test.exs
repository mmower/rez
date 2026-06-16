defmodule Rez.Compiler.ApplyDefaultsTest do
  use ExUnit.Case

  alias Rez.AST.Attribute
  alias Rez.AST.Actor
  alias Rez.Compiler.Compilation
  alias Rez.Compiler.Phases.ApplyDefaults

  defp actor_with_attrs(id, attrs, alias_chain) do
    %Actor{
      id: id,
      attributes: attrs,
      metadata: %{"alias_chain" => alias_chain}
    }
  end

  defp fn_attr(name, params, body) do
    Attribute.arrow_function(name, {params, body})
  end

  defp append_fn_attr(name, params, body) do
    Attribute.append_function(name, {:arrow, params, body})
  end

  defp resolve(actor, defaults) do
    compilation = %Compilation{status: :ok, content: [actor], defaults: defaults}
    [resolved] = ApplyDefaults.run_phase(compilation).content
    %Attribute{type: :function, value: {:arrow, _params, body}} = resolved.attributes["on_init"]
    body
  end

  describe "handler chaining semantics" do
    test "bare instance on_init suppresses defaults + handler" do
      actor = actor_with_attrs("a_test", %{"on_init" => fn_attr("on_init", ["obj", "evt"], "{instance();}")}, ["actor"])
      defaults = %{"actor" => %{"on_init" => append_fn_attr("on_init", ["obj", "evt"], "{appended();}")}}

      body = resolve(actor, defaults)

      assert String.contains?(body, "instance();")
      refute String.contains?(body, "appended();")
    end

    test "instance + chains after defaults bare handler" do
      actor = actor_with_attrs("a_test", %{"on_init" => append_fn_attr("on_init", ["obj", "evt"], "{instance();}")}, ["actor"])
      defaults = %{"actor" => %{"on_init" => fn_attr("on_init", ["obj", "evt"], "{base();}")}}

      body = resolve(actor, defaults)

      assert String.contains?(body, "base();")
      assert String.contains?(body, "instance();")

      {base_pos, _} = :binary.match(body, "base();")
      {instance_pos, _} = :binary.match(body, "instance();")
      assert base_pos < instance_pos
    end

    test "instance + chains after defaults + handler" do
      actor = actor_with_attrs("a_test", %{"on_init" => append_fn_attr("on_init", ["obj", "evt"], "{instance();}")}, ["actor"])
      defaults = %{"actor" => %{"on_init" => append_fn_attr("on_init", ["obj", "evt"], "{defaults();}")}}

      body = resolve(actor, defaults)

      assert String.contains?(body, "defaults();")
      assert String.contains?(body, "instance();")

      {defaults_pos, _} = :binary.match(body, "defaults();")
      {instance_pos, _} = :binary.match(body, "instance();")
      assert defaults_pos < instance_pos
    end

    test "bare instance with no defaults handler runs alone" do
      actor = actor_with_attrs("a_test", %{"on_init" => fn_attr("on_init", ["obj", "evt"], "{instance();}")}, ["actor"])
      defaults = %{}

      body = resolve(actor, defaults)

      assert String.contains?(body, "instance();")
    end

    test "+ handler with no instance becomes sole handler" do
      actor = actor_with_attrs("a_test", %{}, ["actor"])
      defaults = %{"actor" => %{"on_init" => append_fn_attr("on_init", ["obj", "evt"], "{defaults();}")}}

      body = resolve(actor, defaults)

      assert String.contains?(body, "defaults();")
    end

    test "multi-level chain all + runs least-specific first" do
      actor = actor_with_attrs("a_test", %{"on_init" => append_fn_attr("on_init", ["obj", "evt"], "{instance();}")}, ["npc", "actor"])
      defaults = %{
        "npc"   => %{"on_init" => append_fn_attr("on_init", ["obj", "evt"], "{npc();}")},
        "actor" => %{"on_init" => append_fn_attr("on_init", ["obj", "evt"], "{actor();}")}
      }

      body = resolve(actor, defaults)

      assert String.contains?(body, "actor();")
      assert String.contains?(body, "npc();")
      assert String.contains?(body, "instance();")

      {actor_pos, _}    = :binary.match(body, "actor();")
      {npc_pos, _}      = :binary.match(body, "npc();")
      {instance_pos, _} = :binary.match(body, "instance();")

      assert actor_pos < npc_pos
      assert npc_pos < instance_pos
    end

    test "bare at intermediate level suppresses lower, instance + extends it" do
      actor = actor_with_attrs("a_test", %{"on_init" => append_fn_attr("on_init", ["obj", "evt"], "{instance();}")}, ["npc", "actor"])
      defaults = %{
        "npc"   => %{"on_init" => fn_attr("on_init", ["obj", "evt"], "{npc();}")},
        "actor" => %{"on_init" => append_fn_attr("on_init", ["obj", "evt"], "{actor();}")}
      }

      body = resolve(actor, defaults)

      refute String.contains?(body, "actor();")
      assert String.contains?(body, "npc();")
      assert String.contains?(body, "instance();")

      {npc_pos, _}      = :binary.match(body, "npc();")
      {instance_pos, _} = :binary.match(body, "instance();")

      assert npc_pos < instance_pos
    end
  end
end
