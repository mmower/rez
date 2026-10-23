defmodule Rez.Compiler.Phases.CollectConstantsTest do
  use ExUnit.Case

  alias Rez.Compiler.Compilation
  alias Rez.Compiler.Phases.CollectConstants

  defp run(content, keywords) do
    %Compilation{status: :ok, content: content, keywords: MapSet.new(keywords)}
    |> CollectConstants.run_phase()
  end

  test "keyword_const_name PascalCases and prefixes k" do
    assert "kGoblin" == CollectConstants.keyword_const_name("goblin")
    assert "kBigGoblin" == CollectConstants.keyword_const_name("big_goblin")
    assert "kVeryAngryOrc" == CollectConstants.keyword_const_name("very_angry_orc")
  end

  test "folds keywords into the constants map as string constants" do
    %Compilation{status: :ok, constants: constants} = run([], ["goblin", "big_goblin"])

    assert {:string, "goblin"} == constants["kGoblin"]
    assert {:string, "big_goblin"} == constants["kBigGoblin"]
  end

  test "keyword constants coexist with @const declarations" do
    content = [%Rez.AST.Const{name: "MAX_HP", value: {:number, 100}, value_type: :number}]

    %Compilation{status: :ok, constants: constants} = run(content, ["goblin"])

    assert {:number, 100} == constants["MAX_HP"]
    assert {:string, "goblin"} == constants["kGoblin"]
  end

  test "two distinct keywords mapping to the same name is an error" do
    %Compilation{status: :error, errors: [error | _]} = run([], ["big_goblin", "bigGoblin"])

    assert error =~ "conflicting constant names"
  end

  test "a keyword constant colliding with a @const name is an error" do
    content = [%Rez.AST.Const{name: "kGoblin", value: {:string, "x"}, value_type: :string}]

    %Compilation{status: :error, errors: [error | _]} = run(content, ["goblin"])

    assert error =~ "conflict with @const names"
  end

  defp global_elem(id) do
    %Rez.AST.Actor{
      id: id,
      game_element: true,
      attributes: %{"$global" => Rez.AST.Attribute.boolean("$global", true)}
    }
  end

  test "accepts global elements with identifier-safe ids" do
    assert %Compilation{status: :ok} = run([global_elem("player"), global_elem("npc_1")], [])
  end

  test "rejects global elements whose ids are not valid binding names" do
    %Compilation{status: :error, errors: [error | _]} = run([global_elem("my-actor")], [])
    assert error =~ "my-actor"
  end

  test "rejects global elements whose ids are JS reserved words" do
    %Compilation{status: :error, errors: [error | _]} = run([global_elem("class")], [])
    assert error =~ "class"
  end
end
