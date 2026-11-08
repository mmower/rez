defmodule Rez.Compiler.ResolveStyleAssetsTest do
  use ExUnit.Case

  alias Rez.AST.Asset
  alias Rez.AST.Card
  alias Rez.AST.NodeHelper
  alias Rez.AST.Style
  alias Rez.Compiler.Compilation
  alias Rez.Compiler.Phases.ResolveStyleAssets

  @moduletag :tmp_dir

  defp asset(id, dist_path, opts \\ []) do
    %Asset{id: id}
    |> NodeHelper.set_string_attr("$source_path", Keyword.get(opts, :source, dist_path))
    |> NodeHelper.set_string_attr("$dist_path", dist_path)
    |> NodeHelper.set_string_attr("$detected_mime_type", MIME.from_path(dist_path))
    |> NodeHelper.set_boolean_attr("$inline", Keyword.get(opts, :inline, false))
    |> NodeHelper.set_boolean_attr("$template", Keyword.get(opts, :template, false))
  end

  defp run(styles, nodes) do
    compilation = %Compilation{status: :ok, content: [%Style{styles: styles} | nodes]}
    result = ResolveStyleAssets.run_phase(compilation)
    {Enum.find(result.content, &match?(%Style{}, &1)).styles, result}
  end

  defp parchment, do: asset("img_parchment", "assets/images/parchment.png")

  test "replaces a reference with a url" do
    {css, result} = run(".card { background-image: asset(img_parchment); }", [parchment()])

    assert result.status == :ok
    assert css == ~s|.card { background-image: url("assets/images/parchment.png"); }|
  end

  test "replaces multiple references and allows whitespace" do
    nodes = [parchment(), asset("cur_hand", "assets/cursors/hand.png")]

    {css, _} =
      run(".a { background: asset( img_parchment ); cursor: asset(cur_hand), auto; }", nodes)

    assert css ==
             ~s|.a { background: url("assets/images/parchment.png"); cursor: url("assets/cursors/hand.png"), auto; }|
  end

  test "uses a data URL for an inline asset", %{tmp_dir: dir} do
    source = Path.join(dir, "dot.png")
    File.write!(source, <<1, 2, 3>>)
    dot = asset("img_dot", "assets/dot.png", source: source, inline: true)

    {css, _} = run(".a { background: asset(img_dot); }", [dot])

    assert css == ~s|.a { background: url("data:image/png;base64,AQID"); }|
  end

  test "an unknown id is an error" do
    {_, result} = run(".a { background: asset(img_parchmnt); }", [parchment()])

    assert result.status == :error
    assert Enum.any?(result.errors, &(&1 =~ "asset(img_parchmnt) does not refer to an asset"))
  end

  test "an id that is not an asset is an error" do
    {_, result} = run(".a { background: asset(c_intro); }", [%Card{id: "c_intro"}])

    assert result.status == :error
  end

  test "a template asset is not referenceable" do
    template = asset("img_t", "assets/t.png", template: true)
    {_, result} = run(".a { background: asset(img_t); }", [template])

    assert result.status == :error
  end

  test "leaves other text unchanged" do
    styles = ".my-asset(x) { color: #fff; } .b { --fooasset(y): 1; }"
    {css, result} = run(styles, [parchment()])

    assert result.status == :ok
    assert css == styles
  end
end
