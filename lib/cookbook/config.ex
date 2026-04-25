defmodule Rez.Cookbook.Config do
  @moduledoc """
  `Rez.Cookbook.Config` defines static configuration for the cookbook subsystem.
  """

  @cookbook_repo_owner "mmower"
  @cookbook_repo_name "rez-cookbook"
  @cookbook_default_ref "main"
  @cookbook_manifest_file "cookbook.deps"
  @cookbook_dir_name "cookbook"

  def repo_owner, do: @cookbook_repo_owner
  def repo_name, do: @cookbook_repo_name
  def default_ref, do: @cookbook_default_ref
  def manifest_file, do: @cookbook_manifest_file
  def dir_name, do: @cookbook_dir_name

  def raw_file_url(module_path, version_ref) do
    "https://raw.githubusercontent.com/#{@cookbook_repo_owner}/#{@cookbook_repo_name}/#{version_ref}/#{module_path}.rez"
  end

  def raw_lua_url(module_path, version_ref) do
    "https://raw.githubusercontent.com/#{@cookbook_repo_owner}/#{@cookbook_repo_name}/#{version_ref}/#{module_path}.lua"
  end

  def index_url do
    "https://raw.githubusercontent.com/#{@cookbook_repo_owner}/#{@cookbook_repo_name}/main/index.json"
  end

  def releases_latest_url do
    "https://api.github.com/repos/#{@cookbook_repo_owner}/#{@cookbook_repo_name}/releases/latest"
  end

  def tags_url do
    "https://api.github.com/repos/#{@cookbook_repo_owner}/#{@cookbook_repo_name}/git/refs/tags"
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

  def module_file_path(game_root, module_path) do
    Path.join([game_root, "lib", @cookbook_dir_name, "#{module_path}.rez"])
  end

  def module_lua_file_path(game_root, module_path) do
    Path.join([game_root, "lib", @cookbook_dir_name, "#{module_path}.lua"])
  end
end
