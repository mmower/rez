defmodule Rez.Docs do
  @moduledoc """
  `Rez.Docs` implements the `rez docs` command which prints a compact
  reference to the Rez language, written for AI assistants and for authors
  who want a quick reminder rather than a tutorial.

  The reference lives in `assets/docs/rez_reference.md` and is embedded in the
  compiler at build time so that it always matches the installed version.
  Each `## <topic>` heading starts a topic that can be printed on its own.

    rez docs            # print the whole reference
    rez docs topics     # list the topics
    rez docs <topic>    # print one topic
  """

  @reference_path Path.expand("assets/docs/rez_reference.md")
  @external_resource @reference_path
  @reference File.read!(@reference_path)

  # Splits the reference into the preamble (before the first topic) and a
  # list of {topic, summary, text} tuples. The summary is the first non-blank
  # line after the heading.
  @topics @reference
          |> String.split(~r/^(?=## )/m)
          |> Enum.filter(&String.starts_with?(&1, "## "))
          |> Enum.map(fn section ->
            [heading | body] = String.split(section, "\n")
            name = heading |> String.trim_leading("## ") |> String.trim()

            summary =
              body
              |> Enum.map(&String.trim/1)
              |> Enum.find("", &(&1 != ""))

            {name, summary, String.trim_trailing(section)}
          end)

  @doc "Returns the full reference text."
  def reference, do: @reference

  @doc "Returns a list of `{topic, summary}` tuples."
  def topics, do: Enum.map(@topics, fn {name, summary, _} -> {name, summary} end)

  @doc "Returns `{:ok, text}` for the named topic or `:error`."
  def topic(name) do
    case List.keyfind(@topics, String.downcase(name), 0) do
      {_, _, text} -> {:ok, text}
      nil -> :error
    end
  end

  @doc """
  Entry point for `rez docs`. Returns `:ok` or `:error`.
  """
  def run([]) do
    IO.puts(@reference)
    :ok
  end

  def run(["topics" | _]) do
    IO.puts(topic_list())
    :ok
  end

  def run([name | _]) do
    case topic(name) do
      {:ok, text} ->
        IO.puts(text)
        :ok

      :error ->
        IO.puts("Unknown topic '#{name}'.\n")
        IO.puts(topic_list())
        :error
    end
  end

  defp topic_list do
    width = @topics |> Enum.map(&String.length(elem(&1, 0))) |> Enum.max(fn -> 0 end)

    lines =
      Enum.map(topics(), fn {name, summary} ->
        "  #{String.pad_trailing(name, width)}  #{summary}"
      end)

    Enum.join(["Topics (rez docs <topic>):" | lines], "\n")
  end
end
