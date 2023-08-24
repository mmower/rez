defmodule Rez.Compiler.UpdateDeps do
  alias Rez.Compiler.Compilation
  alias Rez.Utils

  @external_resource "node_modules/alpinejs/dist/cdn.min.js"
  @alpine_js File.read!("node_modules/alpinejs/dist/cdn.min.js")
  @alpine_js_time Utils.file_ctime!("node_modules/alpinejs/dist/cdn.min.js")

  @external_resource "node_modules/bulma/css/bulma.min.css"
  @bulma_css File.read!("node_modules/bulma/css/bulma.min.css")
  @bulma_css_time Utils.file_ctime!("node_modules/bulma/css/bulma.min.css")

  @external_resource "node_modules/pluralize/pluralize.js"
  @pluralize_js File.read!("node_modules/pluralize/pluralize.js")
  @pluralize_js_time Utils.file_ctime!("node_modules/pluralize/pluralize.js")

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
      File.write!(Path.join(["assets", folder, file_name]), content)
      %{compilation | progress: ["Updated #{file_name}" | progress]}
    else
      %{compilation | progress: ["#{file_name} is up to date" | progress]}
    end
  end

  def run_phase(%Compilation{status: :ok} = compilation) do
    compilation
    |> conditionally_write_asset("js", "alpinejs.min.js", @alpine_js, @alpine_js_time)
    |> conditionally_write_asset("css", "bulma.min.css", @bulma_css, @bulma_css_time)
    |> conditionally_write_asset("js", "pluralize.js", @pluralize_js, @pluralize_js_time)
  end

  def run_phase(compilation) do
    compilation
  end
end
