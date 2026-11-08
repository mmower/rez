defmodule Rez.LintTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  @game_source """
  %(../lib/stdlib.rez)

  @game {
    name: "lint_test"
    title: "Lint Test"
    author: "Tester"
    IFID: "00000000-0000-0000-0000-000000000000"
    archive_format: 1
    initial_scene_id: #sc_main
    layout: ```${content}```
  }

  @scene sc_main {
    initial_card_id: #c_intro
  }

  @card c_intro {
    CONTENT
  }
  """

  setup do
    cwd = File.cwd!()
    dir = Path.join(System.tmp_dir!(), "rez_lint_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(dir, "src"))

    on_exit(fn ->
      File.cd!(cwd)
      File.rm_rf!(dir)
    end)

    %{dir: dir}
  end

  defp write_game(dir, card_body, extra_source \\ "") do
    source = String.replace(@game_source, "CONTENT", card_body) <> extra_source
    File.write!(Path.join([dir, "src", "game.rez"]), source)
  end

  defp write_asset_file(dir, path) do
    full_path = Path.join([dir, "assets", path])
    File.mkdir_p!(Path.dirname(full_path))
    File.write!(full_path, "x")
  end

  defp lint(dir) do
    options = %{wdir: dir, verbose: 0, write_source: false, ignore_missing_assets: false}

    output =
      capture_io(fn ->
        send(self(), {:result, Rez.Compiler.lint(["src/game.rez"], options)})
      end)

    assert_received {:result, result}
    {result, output}
  end

  test "a valid game lints without writing game files", %{dir: dir} do
    write_game(dir, "content: ```<p>Hello</p>```")

    assert {:ok, output} = lint(dir)
    assert output =~ "no errors found"
    refute File.exists?(Path.join(dir, "dist"))
    refute File.exists?(Path.join(dir, "cache"))
  end

  test "an invalid game reports errors", %{dir: dir} do
    write_game(dir, "title: \"no content\"")

    assert {:error, output} = lint(dir)
    assert output =~ "lint failed"
    assert output =~ "content"
  end

  describe "@asset files" do
    test "file_path is found relative to the assets folder", %{dir: dir} do
      write_asset_file(dir, "audio/theme.mp3")

      write_game(dir, "content: ```<p>Hello</p>```", """
      @asset theme { file_path: "audio/theme.mp3" }
      """)

      assert {:ok, _output} = lint(dir)
    end

    test "a missing file_path is reported", %{dir: dir} do
      write_game(dir, "content: ```<p>Hello</p>```", """
      @asset theme { file_path: "audio/missing.mp3" }
      """)

      assert {:error, output} = lint(dir)
      assert output =~ "'audio/missing.mp3' which does not exist in the assets/ folder"
    end

    test "an asset must have file_name or file_path", %{dir: dir} do
      write_game(dir, "content: ```<p>Hello</p>```", """
      @asset theme { file: "theme.mp3" }
      """)

      assert {:error, output} = lint(dir)
      assert output =~ "You must define file_name or at least one of"
    end
  end
end
