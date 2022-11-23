defmodule Rez.Parser.ParserCache do

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
