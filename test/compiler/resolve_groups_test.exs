defmodule Rez.Compiler.ResolveGroupsTest do
  use ExUnit.Case

  alias Rez.AST.Asset
  alias Rez.AST.Group
  alias Rez.AST.Node
  alias Rez.AST.NodeHelper
  alias Rez.Compiler.Compilation
  alias Rez.Compiler.Phases.ResolveGroups

  defp keywords(tags), do: Enum.map(tags, &{:keyword, &1})

  defp asset(id, file_name, tags, opts \\ []) do
    %Asset{id: id}
    |> NodeHelper.set_string_attr("file_name", file_name)
    |> NodeHelper.set_string_attr("$detected_mime_type", MIME.from_path(file_name))
    |> NodeHelper.set_set_attr("tags", keywords(tags))
    |> NodeHelper.set_boolean_attr("$template", Keyword.get(opts, :template, false))
  end

  defp group(id, type, opts) do
    group =
      %Group{id: id}
      |> NodeHelper.set_keyword_attr("type", type)
      |> NodeHelper.set_set_attr("tags", [])

    Enum.reduce(opts, group, fn {attr, tags}, group ->
      NodeHelper.set_set_attr(group, Atom.to_string(attr), keywords(tags))
    end)
  end

  defp assets do
    [
      asset("hat_01", "hat_01.png", ["hat", "red"]),
      asset("hat_02", "hat_02.png", ["hat", "blue"]),
      asset("cap_01", "cap_01.jpg", ["cap"]),
      asset("hat_song", "hat_song.mp3", ["hat"]),
      asset("untagged", "untagged.png", []),
      asset("hat_template", "hat_t.png", ["hat"], template: true)
    ]
  end

  defp run(content) do
    %Compilation{status: :ok, content: content, progress: [], errors: []}
    |> ResolveGroups.run_phase()
  end

  defp values(compilation, id) do
    compilation
    |> Compilation.content_with_id(id)
    |> NodeHelper.get_attr_value("values")
    |> Enum.map(fn {:string, id} -> id end)
  end

  test "filters by type and include_tags (any-of), ignoring templates" do
    result = run(assets() ++ [group("hats", "image", include_tags: ["hat"])])

    assert :ok = result.status
    assert ["hat_01", "hat_02"] = values(result, "hats")
  end

  test "include_tags matches assets with any of the tags" do
    result = run(assets() ++ [group("headwear", "image", include_tags: ["hat", "cap"])])

    assert ["cap_01", "hat_01", "hat_02"] = values(result, "headwear")
  end

  test "exclude_tags alone excludes assets with any of the tags" do
    result = run(assets() ++ [group("not_hats", "image", exclude_tags: ["hat"])])

    assert ["cap_01", "untagged"] = values(result, "not_hats")
  end

  test "include_tags and exclude_tags can be combined" do
    result =
      run(assets() ++ [group("non_red_hats", "image", include_tags: ["hat"], exclude_tags: ["red"])])

    assert ["hat_02"] = values(result, "non_red_hats")
  end

  test "matches other asset types" do
    result = run(assets() ++ [group("hat_audio", "audio", include_tags: ["hat"])])

    assert ["hat_song"] = values(result, "hat_audio")
  end

  test "falls back to file_name when the mime type was not detected" do
    a =
      %Asset{id: "late"}
      |> NodeHelper.set_string_attr("file_name", "late.png")
      |> NodeHelper.set_set_attr("tags", keywords(["hat"]))

    result = run([a, group("hats", "image", include_tags: ["hat"])])

    assert ["late"] = values(result, "hats")
  end

  test "a group matching no assets is a compile error" do
    result = run(assets() ++ [group("shoes", "image", include_tags: ["shoe"])])

    assert :error = result.status
    assert [message] = result.errors
    assert message =~ "@group shoes"
    assert message =~ "include_tags: :shoe"
  end

  test "js_initializer emits a RezList without the compile-time attributes" do
    result = run(assets() ++ [group("hats", "image", include_tags: ["hat"])])
    js = result |> Compilation.content_with_id("hats") |> Node.js_initializer()

    assert js =~ ~s(new RezList\(\n  "hats")
    assert js =~ ~s("hat_01")
    assert js =~ ~s("hat_02")
    refute js =~ "include_tags"
    refute js =~ "RezGroup"
  end
end
