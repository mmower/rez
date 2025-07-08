defmodule Rez.AST.Asset do
  alias __MODULE__
  alias Rez.AST.NodeHelper

  @moduledoc """
  `Rez.AST.Asset` contains the `Asset` struct and `Node` implementation.

  An `Asset` represents a file on disk that is referenced within the game.
  """

  defstruct status: :ok,
            game_element: true,
            position: {nil, 0, 0},
            id: nil,
            path_info: [],
            attributes: %{},
            metadata: %{},
            validation: nil

  def search(%Asset{} = asset) do
    file_name = Asset.file_name(asset)

    case Path.wildcard("assets/**/#{file_name}") do
      [] ->
        Path.wildcard("assets/**/#{String.normalize(file_name, :nfc)}")

      paths ->
        paths
    end
  end

  def real_asset?(%Asset{} = asset) do
    source_path(asset) != nil
  end

  def script_asset?(%Asset{} = asset) do
    real_asset?(asset) && extension(asset) == ".js"
  end

  def pre_runtime?(%Asset{} = asset) do
    NodeHelper.get_attr_value(asset, "$pre_runtime", false)
  end

  def js_runtime?(%Asset{} = asset) do
    NodeHelper.get_attr_value(asset, "$js_runtime", false)
  end

  def compile_time_script?(%Asset{} = asset) do
    real_asset?(asset) &&
      NodeHelper.instance_node?(asset) &&
      script_asset?(asset) &&
      !js_runtime?(asset)
  end

  def style_asset?(%Asset{} = asset) do
    real_asset?(asset) && extension(asset) == ".css"
  end

  def exists?(%Asset{} = asset) do
    asset |> source_path() |> File.exists?()
  end

  def extension(%Asset{} = asset) do
    asset |> source_path() |> Path.extname()
  end

  def asset_tag(%Asset{} = asset) do
    case extension(asset) do
      ".js" ->
        if NodeHelper.get_attr_value(asset, "$js_defer", false) do
          ~s(<script src="#{Asset.asset_path(asset)}" defer></script>)
        else
          ~s(<script src="#{Asset.asset_path(asset)}"></script>)
        end

      ".css" ->
        ~s(<link rel="stylesheet" href="#{Asset.asset_path(asset)}">)

      ext ->
        ~s(<!-- Unkown asset extension #{ext} cannot embed -->)
    end
  end

  @doc """
  The `file_path` represents the on-disk location of the original asset
  file.
  """
  def source_path(%Asset{} = asset) do
    NodeHelper.get_attr_value(asset, "$source_path")
  end

  def file_name(%Asset{} = asset) do
    NodeHelper.get_attr_value(asset, "file_name")
  end

  @doc """
  The `asset_path` represents the distribution path of the asset file.
  """
  def asset_path(%Asset{} = asset) do
    Path.join("assets", file_name(asset))
  end

  def asset_content(%Asset{} = asset) do
    File.read!(asset_path(asset))
  end

  def read_source(%Asset{} = asset) do
    asset |> source_path() |> File.read!()
  end
end

defimpl Rez.AST.Node, for: Rez.AST.Asset do
  alias Rez.Utils
  alias Rez.AST.Asset
  alias Rez.AST.NodeHelper

  defdelegate js_initializer(asset), to: NodeHelper
  defdelegate html_processor(asset, attr), to: NodeHelper

  def node_type(_asset), do: "asset"

  def js_ctor(asset) do
    NodeHelper.get_attr_value(asset, "$js_ctor", "RezAsset")
  end

  def process(%Asset{} = asset, _) do
    if NodeHelper.get_attr_value(asset, "$template", false) do
      asset
    else
      case Asset.search(asset) do
        [] ->
          %{asset | status: {:error, "Asset not found"}}

        [path] ->
          case Utils.path_readable?(path) do
            :ok ->
              asset
              |> NodeHelper.set_string_attr("$source_path", path)
              |> NodeHelper.set_string_attr("$detected_mime_type", MIME.from_path(path))
              |> then(fn asset ->
                if NodeHelper.get_attr_value(asset, "$inline", false) do
                  NodeHelper.set_string_attr(asset, "content", File.read!(path))
                else
                  file_name = NodeHelper.get_attr_value(asset, "file_name")
                  NodeHelper.set_string_attr(asset, "$dist_path", "assets/#{file_name}")
                end
              end)

            {:error, reason} ->
              %{asset | status: {:error, "Asset file ${path} is unreadable: #{reason}"}}
          end

        _ ->
          %{asset | status: {:error, "Multiple asset files found"}}
      end
    end
  end
end
