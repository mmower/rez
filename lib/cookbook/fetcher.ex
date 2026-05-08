defmodule Rez.Cookbook.Fetcher do
  @moduledoc """
  `Rez.Cookbook.Fetcher` handles HTTP fetching from the cookbook GitHub repository.
  """

  alias Rez.Cookbook.Config

  @doc """
  Fetches a module's `manifest.json` from the cookbook repo.
  Returns `{:ok, map}`, `:not_found`, or `{:error, reason}`.
  """
  def fetch_manifest(module_path, version_ref) do
    url = Config.raw_manifest_url(module_path, version_ref)

    case Req.get(url) do
      {:ok, %{status: 200, body: body}} ->
        result = if is_binary(body), do: Jason.decode(body), else: {:ok, body}

        case result do
          {:ok, map} when is_map(map) -> {:ok, map}
          _ -> {:error, "manifest.json is not a valid JSON object"}
        end

      {:ok, %{status: 404}} ->
        :not_found

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  @doc """
  Fetches a named file from a module's root folder in the cookbook repo.
  Returns `{:ok, binary}` or `{:error, reason}`.
  """
  def fetch_module_file(module_path, filename, version_ref) do
    url = Config.raw_module_file_url(module_path, filename, version_ref)

    case Req.get(url) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status}} -> {:error, "HTTP #{status}"}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  @doc """
  Fetches a named file from a module's docs/ folder in the cookbook repo.
  Returns `{:ok, binary}`, `:not_found`, or `{:error, reason}`.
  """
  def fetch_docs_file(module_path, filename, version_ref) do
    url = Config.raw_docs_file_url(module_path, filename, version_ref)

    case Req.get(url) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: 404}} -> :not_found
      {:ok, %{status: status}} -> {:error, "HTTP #{status}"}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  @doc """
  Fetches the index.json from the cookbook repo's main branch.
  Returns `{:ok, map}` (Req auto-decodes JSON) or `{:error, reason}`.
  """
  def fetch_index do
    case Req.get(Config.index_url(), headers: [{"cache-control", "no-cache"}]) do
      {:ok, %{status: 200, body: body}} ->
        body_str = if is_binary(body), do: body, else: Jason.encode!(body)
        Jason.decode(body_str)

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  @doc """
  Fetches the index and returns a lookup map of module name to its type and version ref.
  Returns `{:ok, %{name => %{"type" => type, "version" => version}}}` or `{:error, reason}`.
  """
  def fetch_module_index do
    case fetch_index() do
      {:ok, %{"modules" => modules}} when is_list(modules) ->
        map =
          modules
          |> Enum.filter(&(is_map(&1) and is_binary(&1["name"])))
          |> Map.new(fn m ->
            version = m["version"] |> to_string() |> ensure_v_prefix()
            {m["name"], %{"type" => m["type"] || "lib", "version" => version}}
          end)

        {:ok, map}

      {:ok, _} ->
        {:error, "index.json has no modules list"}

      {:error, _} = err ->
        err
    end
  end

  defp ensure_v_prefix("v" <> _ = ref), do: ref
  defp ensure_v_prefix(ref), do: "v" <> ref
end
