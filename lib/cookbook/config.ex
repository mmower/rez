defmodule Rez.Cookbook.Config do
  @moduledoc """
  `Rez.Cookbook.Config` defines static configuration for the cookbook subsystem.
  """

  @cookbook_repo_owner "mmower"
  @cookbook_repo_name "rez-cookbook"
  @cookbook_default_ref "main"
  @cookbook_manifest_file "cookbook.toml"
  @cookbook_dir_name "cookbook"

  def repo_owner, do: @cookbook_repo_owner
  def repo_name, do: @cookbook_repo_name
  def default_ref, do: @cookbook_default_ref
  def manifest_file, do: @cookbook_manifest_file
  def dir_name, do: @cookbook_dir_name

  defp base_raw_url do
    "https://raw.githubusercontent.com/#{@cookbook_repo_owner}/#{@cookbook_repo_name}"
  end

  @doc "URL for a module's manifest.json in the repo."
  def raw_manifest_url(module_path, version_ref) do
    "#{base_raw_url()}/#{version_ref}/#{module_path}/manifest.json"
  end

  @doc "URL for a named file inside a module's root folder in the repo."
  def raw_module_file_url(module_path, filename, version_ref) do
    "#{base_raw_url()}/#{version_ref}/#{module_path}/#{filename}"
  end

  @doc "URL for a named file inside a module's docs/ folder in the repo."
  def raw_docs_file_url(module_path, filename, version_ref) do
    "#{base_raw_url()}/#{version_ref}/#{module_path}/docs/#{filename}"
  end

  def index_url do
    "#{base_raw_url()}/main/index.json"
  end

  def manifest_path(game_root) do
    Path.join(game_root, @cookbook_manifest_file)
  end

  def cookbook_lib_path(game_root) do
    Path.join([game_root, "lib", @cookbook_dir_name])
  end

  def cookbook_rez_path(game_root) do
    Path.join([game_root, "lib", "#{@cookbook_dir_name}.rez"])
  end

  @doc "Local directory for all files belonging to a module."
  def module_dir_path(game_root, module_path) do
    Path.join([game_root, "lib", @cookbook_dir_name, module_path])
  end

  @doc "Local path for a named file inside a module's directory."
  def module_file_path(game_root, module_path, filename) do
    Path.join([game_root, "lib", @cookbook_dir_name, module_path, filename])
  end

  @doc "Local docs/ directory for a module."
  def module_docs_dir_path(game_root, module_path) do
    Path.join([game_root, "lib", @cookbook_dir_name, module_path, "docs"])
  end

  @doc "Local path for the rendered HTML docs page."
  def module_docs_html_path(game_root, module_path) do
    Path.join([game_root, "lib", @cookbook_dir_name, module_path, "docs", "index.html"])
  end
end
