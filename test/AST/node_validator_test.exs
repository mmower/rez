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

  test "Searches for parent attributes" do
    asset = %Rez.AST.Asset{
      status: :ok,
      game_element: true,
      position: {"game.rez", 39, 1},
      id: "d6_1",
      path_info: ["assets/img/dice/d6_1.png"],
      attributes: %{
        "$parents" => %Rez.AST.Attribute{
          name: "$parents",
          type: :list,
          value: [keyword: :dice_asset_template]
        }
      }
    }

    template = %Rez.AST.Asset{
      status: :ok,
      game_element: true,
      position: {"", 1, 1},
      id: "dice_asset_template",
      path_info: [],
      attributes: %{
        "$template" => %Rez.AST.Attribute{
          name: "$template",
          type: :boolean,
          value: true
        },
        "width" => %Rez.AST.Attribute{
          name: "width",
          type: :number,
          value: 32
        },
        "height" => %Rez.AST.Attribute{
          name: "height",
          type: :number,
          value: 32
        }
      }
    }

    game =
      %Rez.AST.Game{}
      |> then(fn game -> Rez.AST.Game.add_child(template, game) end)
      |> then(fn game -> Rez.AST.Game.add_child(asset, game) end)

    validator =
      NodeValidator.attribute_if_present?("tags", NodeValidator.attribute_is_keyword_set?())

    assert :ok = validator.(asset, game)
  end
end
