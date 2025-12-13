defmodule Rez.Parser.Parser do
  @moduledoc """
  `Rez.Parser.Parser` implements the main game parser and returns a `Game`
  AST node if parsing is successful.
  """

  alias Rez.Debug
  alias LogicalFile

  alias Ergo.Context
  alias Ergo.Telemetry

  alias Ergo.Terminals
  import Ergo.Combinators

  import Rez.Parser.AliasParsers
  import Rez.Parser.ElementsParser
  import Rez.Parser.SpecialElementParsers
  import Rez.Parser.UtilityParsers
  import Rez.Parser.DirectiveParsers
  import Rez.Parser.ParserCache, only: [cached_parser: 1]

  def bad_element() do
    cached_parser(
      sequence(
        [
          ignore(at()),
          string()
        ],
        label: "bad_element",
        ctx: fn %Context{entry_points: [{line, col} | _], ast: name, data: %{aliases: aliases}} =
                  ctx ->
          ctx
          |> Context.add_error(
            :bad_syntax,
            "Unknown element: #{name} at #{line}:#{col} [Known aliases: #{aliases |> Map.keys() |> Enum.join(", ")}]"
          )
          |> Context.make_error_fatal()
        end
      )
    )
  end

  def game_content() do
    cached_parser(
      sequence(
        [
          iows(),
          lookahead(at()),
          choice([
            element(),
            special_element(),
            directive(),
            alias_directive(),
            aliased_element(),
            bad_element()
          ])
        ],
        label: "game_content"
      )
      |> hoist()
    )
  end

  def top_level() do
    cached_parser(
      sequence(
        [
          many(game_content()),
          iows(),
          ignore(Terminals.eoi())
        ],
        label: "top-level"
      )
      |> hoist()
    )
  end

  def parse(%LogicalFile{} = source, telemetry \\ false) do
    if telemetry, do: Telemetry.start()

    case Ergo.parse(top_level(), to_string(source),
           data: %{source: source, aliases: %{}, id_map: %{}}
         ) do
      %Context{status: :ok, ast: ast, data: %{id_map: id_map}} ->
        if Debug.dbg_do?(:debug) do
          File.write!("idmap.exs", "id_map = " <> inspect(id_map, pretty: true, limit: :infinity))
          File.write!("ast.exs", "ast = " <> inspect(ast, pretty: true, limit: :infinity))
        end

        {:ok, ast, id_map}

      %Context{status: {code, reasons}, id: id, line: line, col: col, input: input}
      when code in [:error, :fatal] ->
        if telemetry,
          do:
            File.write(
              "compiler-output.opml",
              Ergo.Outline.OPML.generate_opml(id, Telemetry.get_events(id))
            )

        {:error, reasons, line, col, input}
    end
  end
end
