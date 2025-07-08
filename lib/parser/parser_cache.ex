defmodule Rez.Parser.ParserCache do
  @moduledoc """
  Implements a cache for Ergo based parsers based on a key.

  The cache is implemented as part of the process dictionary. This is safe
  because Rez is a single-process parser.

  Uses a macro to keep the syntax clean.

  Usage:

  cached_parser(parser)

  It uses the function call site as the cache key.
  """
  defmacro cached_parser(parser) do
    quote do
      Rez.Parser.ParserCache.get_parser(__ENV__.function, fn -> unquote(parser) end)
    end
  end

  def get_parser(key, p_fn) do
    case Process.get(key) do
      nil ->
        parser = p_fn.()
        Process.put(key, parser)
        parser

      parser ->
        parser
    end
  end
end
