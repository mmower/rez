defmodule Rez.AST.NodeValidatorTest do
  use ExUnit.Case
  alias Rez.AST.{NodeValidator, NodeValidator.Validation, Inventory}
  doctest Rez.AST.NodeValidator

  test "Validates required attribute" do
    inventory = %Inventory{id: "inv-1", position: {"test.rez", 1, 1}}

    assert %Validation{
             errors: [
               {_inventory, "Missing required attribute: slots"}
             ],
             validated: ["inventory/inv-1 @ test.rez:1:1"]
           } = NodeValidator.validate(inventory, nil)
  end
end
