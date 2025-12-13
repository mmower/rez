defmodule Rez.Parser.ParserCache do
  @moduledoc """
  Implements a cache for Ergo based parsers based on a key.

  The cache is implemented as part of the process dictionary. This is safe
  because Rez is a single-process parser.

  Uses a macro to keep the syntax clean.

  Usage:

  cached_parser(parser)

  It uses the call site (module + function) as the cache key.

  Cache statistics can be retrieved with `stats/0` and reset with `reset_stats/0`.
  """

  @hits_key {__MODULE__, :__parser_cache_hits__}
  @misses_key {__MODULE__, :__parser_cache_misses__}

  defmacro cached_parser(parser) do
    key = {__CALLER__.module, __CALLER__.function}

    quote do
      Rez.Parser.ParserCache.get_parser(unquote(Macro.escape(key)), fn -> unquote(parser) end)
    end
  end

  def get_parser(key, p_fn) do
    case Process.get(key) do
      nil ->
        increment_misses()
        parser = p_fn.()
        Process.put(key, parser)
        parser

      parser ->
        increment_hits()
        parser
    end
  end

  defp increment_hits do
    Process.put(@hits_key, (Process.get(@hits_key) || 0) + 1)
  end

  defp increment_misses do
    Process.put(@misses_key, (Process.get(@misses_key) || 0) + 1)
  end

  @doc """
  Returns cache statistics as a map with :hits, :misses, :total, and :hit_rate.
  """
  def stats do
    hits = Process.get(@hits_key) || 0
    misses = Process.get(@misses_key) || 0
    total = hits + misses

    hit_rate =
      if total > 0 do
        Float.round(hits / total * 100, 2)
      else
        0.0
      end

    %{
      hits: hits,
      misses: misses,
      total: total,
      hit_rate: hit_rate
    }
  end

  @doc """
  Resets cache statistics to zero.
  """
  def reset_stats do
    Process.put(@hits_key, 0)
    Process.put(@misses_key, 0)
    :ok
  end
end
