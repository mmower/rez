defmodule Rez.Parser.DefaultParser do
  @moduledoc """
  Implements a 'default' parser combinator that is given a parser to execute.
  If that parser returns a nil AST (i.e. did not match) replaces the nil
  with a specific value.

  This is useful for providing a default when parsing optional syntax

  optional(priority()) |> default(100)

  In this example we assume that priority parses a numeric value and returns
  it as the AST. However, if there isn't a priority value the priority parser
  will return nil and the default parser will trigger, adjusting the nil to 100.
  """
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
