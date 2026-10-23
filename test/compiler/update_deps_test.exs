defmodule Rez.Compiler.UpdateDepsTest do
  use ExUnit.Case

  alias Rez.AST.Asset
  alias Rez.AST.Attribute
  alias Rez.Compiler.Phases.UpdateDeps

  defp asset(id, file_name) do
    %Asset{
      id: id,
      attributes: %{
        "file_name" => %Attribute{name: "file_name", type: :string, value: file_name}
      }
    }
  end

  defp installed_file_names(content) do
    content
    |> UpdateDeps.declared_file_names()
    |> UpdateDeps.bundled_assets_to_install()
    |> Enum.map(fn {file_name, _spec} -> file_name end)
    |> Enum.sort()
  end

  test "installs a bundled library the game declares" do
    content = [asset("_BULMA_CSS", "bulma.min.css")]
    assert installed_file_names(content) == ["bulma.min.css"]
  end

  test "skips bundled libraries the game does not declare" do
    # combat.rez-style game: declares no built-in assets
    assert installed_file_names([]) == []
  end

  test "matches by file_name regardless of the asset id" do
    # The author need not use the suggested _ALPINE_JS id
    content = [asset("my_alpine", "alpinejs.min.js")]
    assert installed_file_names(content) == ["alpinejs.min.js"]
  end

  test "ignores assets whose file_name is not a bundled library" do
    content = [asset("portrait", "hero.png"), asset("_PLURALIZE", "pluralize.js")]
    assert installed_file_names(content) == ["pluralize.js"]
  end
end
