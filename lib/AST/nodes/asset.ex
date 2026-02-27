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

  defmodule PluginAPI do
    use Lua.API, scope: "rez.asset"

    def auto_id(file_name) do
      name = Path.rootname(file_name)
      type = Path.extname(file_name) |> String.trim_leading(".")
      "asset_#{name}_#{type}"
    end

    deflua make(id \\ nil, path), state do
      file_name = Path.basename(path)
      id = id || auto_id(file_name)

      # Compute relative path from assets directory to preserve structure
      relative_path =
        if String.starts_with?(path, "assets/") do
          String.replace_prefix(path, "assets/", "")
        else
          file_name
        end

      asset =
        %Rez.AST.Asset{id: id}
        |> NodeHelper.set_string_attr("$source_path", path)
        |> NodeHelper.set_string_attr("file_name", file_name)
        |> NodeHelper.set_string_attr("$detected_mime_type", MIME.from_path(path))
        |> NodeHelper.set_string_attr("$dist_path", "assets/#{relative_path}")
        |> NodeHelper.set_meta(:synthetic, true)

      Lua.encode!(state, {:userdata, asset})
    end
  end

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

  def load_in_head?(%Asset{} = asset) do
    !NodeHelper.get_attr_value(asset, "$load_in_body", false)
  end

  def load_in_body?(%Asset{} = asset) do
    NodeHelper.get_attr_value(asset, "$load_in_body", false)
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
    # Use computed $dist_path if available, fallback for backwards compat
    NodeHelper.get_attr_value(asset, "$dist_path") ||
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
    cond do
      # Synthetic Assets are created via the plugin API
      # and assumed to have a path already
      NodeHelper.get_meta(asset, :synthetic, false) ->
        if NodeHelper.get_attr_value(asset, "$inline", false) do
          NodeHelper.set_string_attr(asset, "content", Asset.read_source(asset))
        else
          asset
        end

      NodeHelper.get_attr_value(asset, "$template", false) ->
        asset

      # file_path specified - exact path, no search
      NodeHelper.has_attr?(asset, "file_path") ->
        handle_file_path(asset)

      # file_name specified - search for file
      true ->
        handle_file_name_search(asset)
    end
  end

  defp handle_file_path(%Asset{} = asset) do
    file_path = NodeHelper.get_attr_value(asset, "file_path")
    full_path = Path.join("assets", file_path)

    case Utils.path_readable?(full_path) do
      :ok ->
        file_name = Path.basename(file_path)

        asset
        |> NodeHelper.set_string_attr("$source_path", full_path)
        |> NodeHelper.set_string_attr("file_name", file_name)
        |> NodeHelper.set_string_attr("$detected_mime_type", MIME.from_path(full_path))
        |> then(fn asset ->
          if NodeHelper.get_attr_value(asset, "$inline", false) do
            NodeHelper.set_string_attr(asset, "content", File.read!(full_path))
          else
            NodeHelper.set_string_attr(asset, "$dist_path", "assets/#{file_path}")
          end
        end)

      {:error, reason} ->
        %{asset | status: {:error, "Asset file not found: #{full_path} (#{reason})"}}
    end
  end

  defp handle_file_name_search(%Asset{} = asset) do
    case Asset.search(asset) do
      [] ->
        %{asset | status: {:error, "Asset not found"}}

      [path] ->
        # Compute relative path for dist (preserves directory structure)
        relative_path = String.replace_prefix(path, "assets/", "")

        case Utils.path_readable?(path) do
          :ok ->
            asset
            |> NodeHelper.set_string_attr("$source_path", path)
            |> NodeHelper.set_string_attr("$detected_mime_type", MIME.from_path(path))
            |> then(fn asset ->
              if NodeHelper.get_attr_value(asset, "$inline", false) do
                NodeHelper.set_string_attr(asset, "content", File.read!(path))
              else
                NodeHelper.set_string_attr(asset, "$dist_path", "assets/#{relative_path}")
              end
            end)

          {:error, reason} ->
            %{asset | status: {:error, "Asset file #{path} is unreadable: #{reason}"}}
        end

      _ ->
        %{asset | status: {:error, "Multiple asset files found"}}
    end
  end
end
