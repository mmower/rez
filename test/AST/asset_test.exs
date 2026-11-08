defmodule Rez.AST.AssetTest do
  use ExUnit.Case

  alias Rez.AST.Asset
  alias Rez.AST.NodeHelper
  alias Rez.Compiler.Phases.WriteGameFile

  @moduletag :tmp_dir

  defp font_asset(dir, file_name, attrs \\ []) do
    path = Path.join(dir, file_name)
    File.write!(path, <<0x77, 0x4F, 0x46, 0x32, 0x00, 0xFF>>)

    Enum.reduce(
      attrs,
      %Asset{id: "font"}
      |> NodeHelper.set_string_attr("$source_path", path)
      |> NodeHelper.set_string_attr("file_name", file_name)
      |> NodeHelper.set_string_attr("$dist_path", "assets/fonts/#{file_name}"),
      fn
        {name, value}, asset when is_binary(value) -> NodeHelper.set_string_attr(asset, name, value)
        {name, value}, asset when is_boolean(value) -> NodeHelper.set_boolean_attr(asset, name, value)
        {name, value}, asset when is_number(value) -> NodeHelper.set_number_attr(asset, name, value)
      end
    )
  end

  describe "font_asset?/1" do
    test "is true for a font file with font_family", %{tmp_dir: dir} do
      for file <- ["a.woff2", "b.woff", "c.ttf", "d.OTF"] do
        assert Asset.font_asset?(font_asset(dir, file, [{"font_family", "Body"}]))
      end
    end

    test "is false for a font file without font_family", %{tmp_dir: dir} do
      refute Asset.font_asset?(font_asset(dir, "a.woff2"))
    end

    test "is false for a non-font file with font_family", %{tmp_dir: dir} do
      refute Asset.font_asset?(font_asset(dir, "a.png", [{"font_family", "Body"}]))
    end
  end

  describe "font_face/1" do
    test "uses defaults and the dist path", %{tmp_dir: dir} do
      css = Asset.font_face(font_asset(dir, "Body.woff2", [{"font_family", "Body"}]))

      assert css ==
               ~s|@font-face { font-family: "Body"; src: url("assets/fonts/Body.woff2") format("woff2"); font-weight: 400; font-style: normal; font-display: swap; }|
    end

    test "uses supplied attributes and the right format", %{tmp_dir: dir} do
      css =
        Asset.font_face(
          font_asset(dir, "Body.ttf", [
            {"font_family", ~s|My "Font"|},
            {"font_weight", 700},
            {"font_style", "italic"},
            {"font_display", "block"}
          ])
        )

      assert css =~ ~s|font-family: "My \\"Font\\"";|
      assert css =~ ~s|format("truetype")|
      assert css =~ "font-weight: 700;"
      assert css =~ "font-style: italic;"
      assert css =~ "font-display: block;"
    end

    test "embeds inline fonts as a data URL", %{tmp_dir: dir} do
      css =
        Asset.font_face(font_asset(dir, "Body.woff2", [{"font_family", "Body"}, {"$inline", true}]))

      assert css =~ ~s|url("data:font/woff2;base64,d09GMgD/")|
    end
  end

  describe "preload_font?/1" do
    test "is true only for non-inline font assets with $preload", %{tmp_dir: dir} do
      assert Asset.preload_font?(
               font_asset(dir, "a.woff2", [{"font_family", "Body"}, {"$preload", true}])
             )

      refute Asset.preload_font?(font_asset(dir, "a.woff2", [{"font_family", "Body"}]))

      refute Asset.preload_font?(
               font_asset(dir, "a.woff2", [
                 {"font_family", "Body"},
                 {"$preload", true},
                 {"$inline", true}
               ])
             )
    end

    test "preload_tag/1 includes type and crossorigin", %{tmp_dir: dir} do
      tag = Asset.preload_tag(font_asset(dir, "a.woff2", [{"font_family", "Body"}]))

      assert tag ==
               ~s|<link rel="preload" href="assets/fonts/a.woff2" as="font" type="font/woff2" crossorigin>|
    end
  end

  describe "WriteGameFile.font_assets/1" do
    test "selects only font assets", %{tmp_dir: dir} do
      font = font_asset(dir, "a.woff2", [{"font_family", "Body"}])
      plain = font_asset(dir, "b.woff2")
      image = font_asset(dir, "c.png")

      assert WriteGameFile.font_assets([font, plain, image]) == [font]
    end
  end
end
