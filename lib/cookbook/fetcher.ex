defmodule Rez.Cookbook.Fetcher do
  @moduledoc """
  `Rez.Cookbook.Fetcher` handles HTTP fetching from the cookbook GitHub repository.
  """

  alias Rez.Cookbook.Config

  @doc """
  Fetches a module's `.rez` source from the cookbook repo.
  Returns `{:ok, binary}` or `{:error, reason}`.
  """
  def fetch_module(module_path, version_ref) do
    url = Config.raw_file_url(module_path, version_ref)

    case Req.get(url) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status}} -> {:error, "HTTP #{status}"}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  @doc """
  Fetches the index.json from the cookbook repo's main branch.
  Returns `{:ok, map}` (Req auto-decodes JSON) or `{:error, reason}`.
  """
  def fetch_index do
    case Req.get(Config.index_url()) do
      {:ok, %{status: 200, body: body}} ->
        body_str = if is_binary(body), do: body, else: Jason.encode!(body)
        Jason.decode(body_str)

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end
end
