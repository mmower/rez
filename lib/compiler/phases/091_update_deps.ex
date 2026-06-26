defmodule Rez.Compiler.Phases.UpdateDeps do
  @moduledoc """
  Implements the update dependencies phase of the Rez compiler.

  Rez bundles copies of Alpine.JS, Bulma CSS, and Pluralize, but these are
  opt-in: an author activates one by declaring an `@asset` whose `file_name`
  matches the bundled file (so they are free to use, e.g., TailwindCSS
  instead). For each bundled library the game actually declares, this phase
  checks that the on-disk copy is current with the version embedded in the
  binary and, if not, writes the new one out.

  This phase runs after `ConsolidateNodes` so that the parsed `@asset` nodes
  are available, and before `ApplySchema` so that the files exist by the time
  the `:file_exists` schema rule validates them.
  """
  alias Rez.Compiler.Compilation
  alias Rez.AST.NodeHelper
  alias Rez.Utils
  alias Rez.Compiler.IOError

  @external_resource "node_modules/alpinejs/dist/cdn.min.js"
  @alpine_js File.read!("node_modules/alpinejs/dist/cdn.min.js")
  @alpine_js_time Utils.file_ctime!("node_modules/alpinejs/dist/cdn.min.js")

  @external_resource "node_modules/bulma/css/bulma.min.css"
  @bulma_css File.read!("node_modules/bulma/css/bulma.min.css")
  @bulma_css_time Utils.file_ctime!("node_modules/bulma/css/bulma.min.css")

  @external_resource "node_modules/pluralize/pluralize.js"
  @pluralize_js File.read!("node_modules/pluralize/pluralize.js")
  @pluralize_js_time Utils.file_ctime!("node_modules/pluralize/pluralize.js")

  # Maps each bundled library's on-disk file_name to {asset folder, contents,
  # embedded ctime}. The file_name (not the node_modules source name) is the
  # key, e.g. Alpine ships from cdn.min.js but is written as alpinejs.min.js.
  @bundled_assets %{
    "alpinejs.min.js" => {"js", @alpine_js, @alpine_js_time},
    "bulma.min.css" => {"css", @bulma_css, @bulma_css_time},
    "pluralize.js" => {"js", @pluralize_js, @pluralize_js_time}
  }

  def asset_requires_update?(folder, file_name, stored_ctime) do
    file_path = Path.join(["assets", folder, file_name])

    case File.exists?(file_path) do
      false ->
        true

      true ->
        file_ctime = Utils.file_ctime!(file_path)
        stored_ctime > file_ctime
    end
  end

  def conditionally_write_asset(
        %Compilation{progress: progress} = compilation,
        folder,
        file_name,
        content,
        ctime
      ) do
    if asset_requires_update?(folder, file_name, ctime) do
      dest_path = Path.join(["assets", folder, file_name])
      File.mkdir_p(Path.dirname(dest_path))

      case File.write(dest_path, content) do
        :ok ->
          %{compilation | progress: ["Updated #{file_name}" | progress]}

        {:error, code} ->
          IOError.file_write_error(compilation, code, "Asset #{file_name}", dest_path)
      end
    else
      %{compilation | progress: ["#{file_name} is up to date" | progress]}
    end
  end

  @doc """
  The set of `file_name` values declared by `@asset` elements in the game. A
  bundled library is installed only when the game declares an `@asset` whose
  `file_name` matches it (the asset's id is irrelevant).
  """
  def declared_file_names(content) do
    content
    |> NodeHelper.filter_elem(Rez.AST.Asset)
    |> Enum.map(&NodeHelper.get_attr_value(&1, "file_name"))
    |> MapSet.new()
  end

  @doc """
  The `{file_name, {folder, content, ctime}}` entries for the bundled libraries
  that the game has declared (and therefore should be installed).
  """
  def bundled_assets_to_install(declared_file_names) do
    Enum.filter(@bundled_assets, fn {file_name, _spec} ->
      MapSet.member?(declared_file_names, file_name)
    end)
  end

  def run_phase(%Compilation{status: :ok, content: content} = compilation) do
    content
    |> declared_file_names()
    |> bundled_assets_to_install()
    |> Enum.reduce(compilation, fn {file_name, {folder, content, ctime}}, compilation ->
      conditionally_write_asset(compilation, folder, file_name, content, ctime)
    end)
  end

  def run_phase(compilation) do
    compilation
  end
end
