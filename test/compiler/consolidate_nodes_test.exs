defmodule Rez.Compiler.ConsolidateNodesTest do
  use ExUnit.Case

  alias Rez.Compiler.Compilation
  alias Rez.Compiler.Phases.ConsolidateNodes

  test "Pass through" do
    game = %Rez.AST.Game{id: "game", attributes: %{:a => 1, :b => 2, :c => 3}}
    scene = %Rez.AST.Scene{id: "s_intro", attributes: %{:a => :a, :b => :b, :c => :c}}

    pre_compilation = %Compilation{
      status: :ok,
      content: [game, scene]
    }

    post_compilation = ConsolidateNodes.run_phase(pre_compilation)

    assert :ok = post_compilation.status
    assert [^game, ^scene] = post_compilation.content
  end

  test "Merges nodes with the same id" do
    o_1 = %Rez.AST.Object{id: "o_1", attributes: %{:a => 1, :b => 2, :c => 3}}
    o_2 = %Rez.AST.Object{id: "o_2", attributes: %{:d => 4, :e => 5, :f => 6}}
    o_3 = %Rez.AST.Object{id: "o_1", attributes: %{:b => 2, :c => 4, :e => 5}}

    pre_compilation = %Compilation{
      status: :ok,
      content: [o_1, o_2, o_3]
    }

    post_compilation = ConsolidateNodes.run_phase(pre_compilation)

    assert :ok = post_compilation.status

    assert [
             %Rez.AST.Object{id: "o_1", attributes: %{:a => 1, :b => 2, :c => 4, :e => 5}},
             ^o_2
           ] = post_compilation.content
  end

  test "Errors when the same id is used by different element types" do
    actor = %Rez.AST.Actor{id: "heavy", attributes: %{}}
    object = %Rez.AST.Object{id: "heavy", attributes: %{}}

    pre_compilation = %Compilation{
      status: :ok,
      content: [actor, object]
    }

    post_compilation = ConsolidateNodes.run_phase(pre_compilation)

    assert :error = post_compilation.status
    assert [error] = post_compilation.errors
    assert error =~ "heavy"
    assert error =~ "actor"
    assert error =~ "object"
  end
end
