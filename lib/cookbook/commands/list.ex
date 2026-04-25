defmodule Rez.Cookbook.Commands.List do
  alias Rez.Cookbook.Fetcher

  def run(_game_root) do
    IO.puts("Fetching module list from mmower/rez-cookbook...")

    tag = case Fetcher.fetch_latest_tag() do
      {:ok, t} -> t
      {:error, _} -> nil
    end

    case Fetcher.fetch_index() do
      {:ok, body} when is_map(body) ->
        print_modules(Map.get(body, "modules", []), tag)
        :ok

      {:ok, _} ->
        IO.puts("Error: index.json has unexpected format")
        :error

      {:error, reason} ->
        IO.puts("Error fetching index: #{reason}")
        :error
    end
  end

  defp print_modules([], _tag) do
    IO.puts("No modules available yet.")
  end

  defp print_modules(modules, tag) do
    ref = tag || "main"
    IO.puts("\nAvailable modules (mmower/rez-cookbook @ #{ref}):\n")

    name_width = modules |> Enum.map(&String.length(&1["name"] || "")) |> Enum.max()

    Enum.each(modules, fn module ->
      name = module["name"] || "?"
      type = module["type"] || "lib"
      desc = module["description"] || ""
      author = module["author"]
      since = module["since"]
      meta = [if(author, do: "by #{author}"), if(since, do: "since #{since}")] |> Enum.reject(&is_nil/1) |> Enum.join(", ")
      meta_str = if meta != "", do: "  (#{meta})", else: ""
      IO.puts("  #{String.pad_trailing(name, name_width)}  [#{type}]  #{desc}#{meta_str}")
    end)

    IO.puts("")
  end
end
