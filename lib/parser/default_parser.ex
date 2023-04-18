defmodule Rez.Parser.DefaultParser do
  alias Ergo.{Context, Parser}

  def default(%Parser{} = parser, value) do
    Parser.combinator(
      :default,
      "default->#{inspect(value)}",
      fn %Context{} = ctx ->
        case Parser.invoke(ctx, parser) do
          %Context{status: :ok, ast: nil} = nil_ctx ->
            %{nil_ctx | ast: value}

          new_ctx ->
            new_ctx
        end
      end
    )
  end
end
