defmodule Rez.Compiler.Config do
  @moduledoc """
  `Rez.Compiler.Config` defines static configuration of the compiler.
  """

  @asset_path_name "assets"
  def asset_path_name() do
    @asset_path_name
  end

  @dist_path_name "dist"
  def dist_path_name() do
    @dist_path_name
  end

  @src_path_name "src"
  def src_path_name() do
    @src_path_name
  end
end
