defmodule Rez.Compiler.SystemLifecycleSchemaTest do
  @moduledoc """
  Tests the @system schema's handler requirement after adding the lifecycle path.

  A @system must define at least one of before_event, after_event,
  before_lifecycle_event, or after_lifecycle_event. The four handlers are wired
  together with `or:` rules so any single one satisfies the requirement, mirroring
  the @schema system definition in stdlib.rez.eex.
  """
  use ExUnit.Case

  alias Rez.AST.Attribute
  alias Rez.Compiler.SchemaBuilder
  alias Rez.Compiler.Phases.ApplySchema

  # Mirrors the four handler rules from @schema system in stdlib.rez.eex
  defp handler_rules() do
    [
      SchemaBuilder.build("before_event", [
        {:kind, [:function]},
        {:param_count, 2},
        {:or, ["after_event", "before_lifecycle_event", "after_lifecycle_event"]}
      ]),
      SchemaBuilder.build("after_event", [
        {:kind, [:function]},
        {:param_count, 3},
        {:or, ["before_event", "before_lifecycle_event", "after_lifecycle_event"]}
      ]),
      SchemaBuilder.build("before_lifecycle_event", [
        {:kind, [:function]},
        {:param_count, 3},
        {:or, ["before_event", "after_event", "after_lifecycle_event"]}
      ]),
      SchemaBuilder.build("after_lifecycle_event", [
        {:kind, [:function]},
        {:param_count, 4},
        {:or, ["before_event", "after_event", "before_lifecycle_event"]}
      ])
    ]
    |> Enum.map(fn {:ok, rules} -> rules end)
    |> List.flatten()
  end

  defp system_with(attributes) do
    %Rez.AST.System{
      id: "sys_test",
      attributes: attributes,
      metadata: %{"alias_chain" => ["system"]}
    }
  end

  defp fn_attr(name, params) do
    Attribute.arrow_function(name, {params, "{}"})
  end

  test "a system defining only before_lifecycle_event validates" do
    system =
      system_with(%{
        "before_lifecycle_event" =>
          fn_attr("before_lifecycle_event", ["system", "event_name", "params"])
      })

    result = ApplySchema.apply_schema_to_node(system, handler_rules(), %{})
    assert [] = result.validation.errors
  end

  test "a system defining only after_lifecycle_event validates" do
    system =
      system_with(%{
        "after_lifecycle_event" =>
          fn_attr("after_lifecycle_event", ["system", "event_name", "params", "result"])
      })

    result = ApplySchema.apply_schema_to_node(system, handler_rules(), %{})
    assert [] = result.validation.errors
  end

  test "a system defining no handler fails the or requirement" do
    system = system_with(%{})

    result = ApplySchema.apply_schema_to_node(system, handler_rules(), %{})
    assert length(result.validation.errors) > 0
  end

  test "a lifecycle handler of the wrong arity is rejected" do
    system =
      system_with(%{
        # before_lifecycle_event must be a 3-param function (system, event_name, params)
        "before_lifecycle_event" => fn_attr("before_lifecycle_event", ["system", "event_name"])
      })

    result = ApplySchema.apply_schema_to_node(system, handler_rules(), %{})

    assert Enum.any?(result.validation.errors, fn {_, _, msg} ->
             String.contains?(msg, "before_lifecycle_event") and String.contains?(msg, "params")
           end)
  end
end
