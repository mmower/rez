defmodule Rez.Compiler.Phases.ResolveStyleAssets do
  @moduledoc """
  Replaces `asset(id)` references in `@styles` blocks with a CSS
  `url("...")` value for the asset, e.g.

      .card { background-image: asset(img_parchment); }

  becomes

      .card { background-image: url("assets/images/parchment.png"); }

  An `$inline` asset is referenced as a `data:` URL instead. Referring to an
  id that is not an asset is a compile error.

  This runs after assets have been processed, so that their dist paths are
  known.
  """
  alias Rez.AST.Asset
  alias Rez.AST.NodeHelper
  alias Rez.AST.Style
  alias Rez.Compiler.Compilation

  @asset_ref ~r/(?<![\w-])asset\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)/

  def run_phase(%Compilation{status: :ok, content: content} = compilation) do
    assets =
      content
      |> Enum.filter(&match?(%Asset{}, &1))
      |> Enum.reject(&NodeHelper.template_node?/1)
      |> Map.new(&{&1.id, &1})

    {content, compilation} =
      Enum.map_reduce(content, compilation, fn
        %Style{} = style, compilation -> resolve_style(style, assets, compilation)
        node, compilation -> {node, compilation}
      end)

    %{compilation | content: content}
  end

  def run_phase(compilation), do: compilation

  defp resolve_style(%Style{styles: styles} = style, assets, compilation) do
    case unknown_ids(styles, assets) do
      [] ->
        {%{style | styles: resolve_refs(styles, assets)}, compilation}

      ids ->
        {style, Enum.reduce(ids, compilation, &Compilation.add_error(&2, error(&1)))}
    end
  end

  @doc """
  Replaces each `asset(id)` in `styles` with the asset's CSS `url(...)`.
  Assumes every referenced id is present in `assets`.
  """
  def resolve_refs(styles, assets) do
    Regex.replace(@asset_ref, styles, fn _, id -> Asset.css_url(Map.fetch!(assets, id)) end)
  end

  @doc """
  Returns the ids referenced by `asset(id)` in `styles` that are not assets.
  """
  def unknown_ids(styles, assets) do
    @asset_ref
    |> Regex.scan(styles, capture: :all_but_first)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.reject(&Map.has_key?(assets, &1))
  end

  defp error(id), do: "@styles: asset(#{id}) does not refer to an asset"
end
