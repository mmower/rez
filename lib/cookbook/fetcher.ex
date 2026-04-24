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
  Fetches the latest release tag from the cookbook GitHub repo.
  Tries the releases API first, falls back to the tags API.
  Returns `{:ok, "0.1.1"}` or `{:error, reason}`.
  """
  def fetch_latest_tag do
    release_tag = case Req.get(Config.releases_latest_url(), headers: [{"Accept", "application/vnd.github+json"}]) do
      {:ok, %{status: 200, body: body}} ->
        tag = if is_map(body), do: body["tag_name"], else: (with {:ok, decoded} <- Jason.decode(body), do: decoded["tag_name"])
        if is_binary(tag) and tag != "", do: tag, else: nil
      _ -> nil
    end

    case fetch_latest_tag_from_tags_api() do
      {:ok, tag_tag} ->
        best = highest_semver(Enum.reject([release_tag, tag_tag], &is_nil/1))
        if best, do: {:ok, best}, else: {:error, "No valid version tags found in cookbook repository"}
      {:error, _} = err ->
        if release_tag, do: {:ok, release_tag}, else: err
    end
  end

  defp fetch_latest_tag_from_tags_api do
    case Req.get(Config.tags_url(), headers: [{"Accept", "application/vnd.github+json"}]) do
      {:ok, %{status: 200, body: body}} ->
        tags = if is_list(body), do: body, else: (with {:ok, decoded} <- Jason.decode(body), do: decoded)
        names = for %{"ref" => ref} <- tags,
                    is_binary(ref),
                    name = String.replace_prefix(ref, "refs/tags/", ""),
                    name != ref,
                    do: name
        case highest_semver(names) do
          nil -> {:error, "No tags found in cookbook repository"}
          name -> {:ok, name}
        end

      {:ok, %{status: status}} ->
        {:error, "GitHub tags API returned HTTP #{status}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  defp highest_semver([]), do: nil
  defp highest_semver(names) do
    names
    |> Enum.filter(&semver?/1)
    |> Enum.max_by(&parse_semver/1, fn -> nil end)
  end

  defp semver?(name) do
    name = String.trim_leading(name, "v")
    match?({:ok, _}, Version.parse(name))
  end

  defp parse_semver(name) do
    name = String.trim_leading(name, "v")
    {:ok, v} = Version.parse(name)
    v
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
