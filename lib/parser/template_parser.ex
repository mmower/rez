defmodule Rez.Parser.TemplateParser do
  alias Ergo.Terminals, as: T
  alias Ergo.Combinators, as: C
  alias Ergo.Meta, as: M
  alias Rez.Parser.TemplateExpressionParser, as: TEP
  alias Rez.Parser.ParserCache, as: PC

  def forward_slash(), do: T.char(?\\)
  def dollar(), do: T.char(?$)
  def open_brace(), do: T.char(?{)
  def close_brace(), do: T.char(?})
  # def interpolate(), do: T.literal("{{")

  def cancel_interpolation_marker() do
    T.literal("\\$") |> C.replace("$")
  end

  def interpolation() do
    C.sequence(
      [
        C.ignore(T.literal("${")),
        M.commit(),
        C.many(
          C.sequence([
            C.not_lookahead(close_brace()),
            T.any()
          ]),
          ast: fn ast -> List.to_string(ast) |> String.trim() end
        ),
        C.ignore(close_brace())
      ],
      ast: fn [expr | _] ->
        case TEP.parse(expr) do
          {:ok, ex} ->
            {:interpolate, ex}

          error ->
            error
        end
      end
    )
  end

  def open_helper(), do: PC.get_parser("open_helper", fn -> T.literal("{{") end)
  def close_helper(), do: PC.get_parser("close_helper", fn -> T.literal("}}") end)

  def helper() do
    C.sequence([
      C.ignore(open_helper()),
      M.commit(),
      C.many(
        C.sequence([
          C.not_lookahead(close_helper()),
          T.any()
        ])
      ),
      C.ignore(close_helper())
    ])
  end

  def string() do
    char_parser =
      C.sequence([
        C.not_lookahead(
          C.choice([
            T.literal("${"),
            T.literal("\\$")
          ])
        ),
        T.any()
      ])

    C.sequence(
      [
        char_parser,
        C.many(char_parser)
      ],
      ast: fn ast -> ast |> List.flatten() |> List.to_string() end
    )
  end

  def template_parser() do
    C.many(
      C.choice([
        cancel_interpolation_marker(),
        interpolation(),
        helper(),
        string()
      ]),
      ast: fn ast -> {:template, ast} end
    )
  end

  def parse(s) do
    case Ergo.parse(template_parser(), s) do
      %{status: :ok, ast: ast} ->
        ast

      %{status: {:fatal, error}} ->
        {:error, error}

      %{status: {:error, error}} ->
        {:error, error}
    end
  end
end
