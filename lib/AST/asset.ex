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
            attributes: %{}

  def search(%Asset{} = asset) do
    file_name = Asset.file_name(asset)

    case Path.wildcard("assets/**/#{file_name}") do
      [] ->
        Path.wildcard("assets/**/#{String.normalize(file_name, :nfc)}")

      paths ->
        paths
    end
  end

  def exists?(%Asset{} = asset) do
    File.exists?(file_path(asset))
  end

  def script_asset?(%Asset{} = asset) do
    ext(asset) == ".js"
  end

  def pre_runtime?(%Asset{} = asset) do
    NodeHelper.get_attr_value(asset, "pre_runtime", false)
  end

  def js_runtime?(%Asset{} = asset) do
    NodeHelper.get_attr_value(asset, "js_runtime", false)
  end

  def style_asset?(%Asset{} = asset) do
    ext(asset) == ".css"
  end

  def ext(%Asset{} = asset) do
    Path.extname(file_path(asset))
  end

  def asset_tag(%Asset{} = asset) do
    case Path.extname(file_path(asset)) do
      ".js" ->
        if NodeHelper.get_attr_value(asset, "defer", false) do
          ~s(<script src="#{Asset.asset_path(asset)}" defer></script>)
        else
          ~s(<script src="#{Asset.asset_path(asset)}"></script>)
        end

      ".css" ->
        ~s(<link rel="stylesheet" href="#{Asset.asset_path(asset)}">)
    end
  end

  @doc """
  The `file_path` represents the on-disk location of the original asset
  file.
  """
  def file_path(%Asset{} = asset) do
    NodeHelper.get_attr_value(asset, "$path")
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
end

defimpl Rez.AST.Node, for: Rez.AST.Asset do
  import Rez.AST.NodeValidator
  alias Rez.AST.Asset
  alias Rez.AST.NodeHelper

  defdelegate js_initializer(asset), to: NodeHelper

  def node_type(_asset), do: "asset"

  def js_ctor(asset) do
    NodeHelper.get_attr_value(asset, "js_ctor", "RezAsset")
  end

  def default_attributes(_asset), do: %{}

  def pre_process(asset) do
    # Template assets should not define a path or be searched for
    if !NodeHelper.get_attr_value(asset, "$template", false) do
      %{asset | path_info: Asset.search(asset)}
    else
      asset
    end
  end

  def process(%Asset{path_info: [path]} = asset) do
    asset
    |> NodeHelper.set_string_attr("$path", path)
    |> NodeHelper.set_string_attr("detected_mime_type", MIME.from_path(path))
  end

  def process(%Asset{} = asset), do: asset

  def children(_asset), do: []

  def refers_to_existing_file?(chained_validator \\ nil) do
    fn attr, %{path_info: path_info} = asset, game ->
      case {path_info, is_nil(chained_validator)} do
        {[], _} ->
          if NodeHelper.get_attr_value(asset, "_ignore_missing") do
            :ok
          else
            {:error, "Cannot find asset file: |#{NodeHelper.get_attr_value(asset, "file_name")}|"}
          end

        {[_path], true} ->
          :ok

        {[_path], false} ->
          chained_validator.(attr, asset, game)

        {_, _} ->
          {:error,
           "Multiple possible paths for asset: |#{NodeHelper.get_attr_value(asset, "file_name")}|"}
      end
    end
  end

  def validators(%Asset{} = _asset) do
    [
      attribute_if_present?(
        "tags",
        attribute_is_keyword_set?()
      ),
      attribute_if_present?(
        "js_ctor",
        attribute_has_type?(:string)
      ),
      attribute_if_present?(
        "js_runtime",
        attribute_has_type?(
          :boolean,
          other_attributes_present?(["js_depends"])
        )
      ),
      attribute_if_present?(
        "js_depends",
        attribute_coll_of?(:string)
      ),
      attribute_if_present?(
        "pre_runtime",
        attribute_has_type?(:boolean)
      ),
      attribute_present?(
        "file_name",
        attribute_has_type?(
          :string,
          refers_to_existing_file?()
        )
      ),
      attribute_if_present?(
        "width",
        attribute_has_type?(:string)
      ),
      attribute_if_present?(
        "height",
        attribute_has_type?(:string)
      )
    ]
  end
end
