defmodule Rez.Parser.ValueParsers do
  alias Ergo.Context
  import Ergo.Combinators
  import Ergo.Terminals
  import Ergo.Numeric
  import Ergo.Meta
  import Rez.Parser.IdentifierParser
  import Rez.Parser.UtilityParsers
  import Rez.Utils

  # String

  def string_err_wrap(%Context{status: {:error, :unexpected_character}} = ctx) do
    %{ctx | status: {:error, :string_error}}
  end

  def string_err_wrap(context) do
    context
  end

  def string_value() do
    sequence(
      [
        ignore(double_quote()),
        many(not_double_quote()) |> string,
        ignore(double_quote())
      ],
      ast: fn [string] ->
        if String.match?(string, ~r/\$\{.*\}/) do
          {:dstring, string}
        else
          {:string, string}
        end
      end,
      err: &string_err_wrap/1,
      debug: true,
      label: "string-value"
    )
  end

  # Heredoc

  @doc ~S"""
  Trims a leading \n (and optional \r) from a string

  ## Examples
      iex> import Rez.Parser.AttributeParser
      iex> assert "foo" = trim_leading_carriage_return("\nfoo")
      iex> assert "foo" = trim_leading_carriage_return("\r\nfoo")
      iex> assert "foo" = trim_leading_carriage_return("foo")
  """
  def trim_leading_carriage_return(s) do
    Regex.replace(~r/\A\r?\n/, s, "")
  end

  @doc ~S"""
  Trims a trailing \n or \r\n from a string

  ## Examples
      iex> import Rez.Parser.AttributeParser
      iex> assert "foo" = trim_tailing_carriage_return("foo\n")
      iex> assert "foo" = trim_tailing_carriage_return("foo\r\n")
      iex> assert "foo" = trim_tailing_carriage_return("foo")
  """
  def trim_tailing_carriage_return(s) do
    Regex.replace(~r/\r?\n\z/, s, "")
  end

  def trim_leading_space(s) do
    lines = string_to_lines(s)
    first_line = List.first(lines)
    new_first_line = String.replace_leading(first_line, " ", "")
    leading_spaces_count = String.length(first_line) - String.length(new_first_line)
    leading_match = String.duplicate(" ", leading_spaces_count)

    Enum.map_join(
      lines,
      "\n",
      fn line -> String.replace_prefix(line, leading_match, "") end)
  end

  def convert_heredoc_to_string(chars) do
    chars
    |> List.to_string()
    |> trim_leading_carriage_return()
    |> trim_tailing_carriage_return()
    |> trim_leading_space()
  end

  def heredoc_value() do
    sequence(
      [
        ignore(literal("\"\"\"")),
        many(
          sequence([
            not_lookahead(literal("\"\"\"")),
            any()
          ]),
          ast: fn chars -> convert_heredoc_to_string(chars) end
        ),
        ignore(literal("\"\"\""))
      ],
      label: "here-doc",
      debug: true,
      ast: fn [str] -> {:string, str} end
    )
  end

  # Bool

  @doc """
  ## Examples
      iex> alias Ergo
      iex> alias Ergo.Context
      iex> import Rez.Parser.AttributeParser
      iex> assert %Context{status: :ok, ast: {:boolean, true}} = Ergo.parse(bool_value(), "true")
      iex> assert %Context{status: :ok, ast: {:boolean, true}} = Ergo.parse(bool_value(), "yes")
      iex> assert %Context{status: :ok, ast: {:boolean, false}} = Ergo.parse(bool_value(), "false")
      iex> assert %Context{status: :ok, ast: {:boolean, false}} = Ergo.parse(bool_value(), "no")
  """
  def bool_value() do
    choice(
      [
        choice([
          literal("true"),
          literal("yes")]) |> transform(fn _ -> {:boolean, true} end),
        choice([
          literal("false"),
          literal("no")]) |> transform(fn _ -> {:boolean, false} end)
      ],
      label: "boolean-value",
      debug: true
    )
  end

  # Number

  def number_value() do
    number() |> transform(fn number -> {:number, number} end)
  end

  # Keyword

  def keyword_value() do
    sequence(
      [
      ignore(colon()),
      many(char([?_, ?$, [?a..?z], [?A..?Z], [?0..?9]], label: "kw_char"), min: 1)
      ],
      label: "keyword-value",
      debug: true,
      ast: fn [keyword_chars] -> {:keyword, List.to_string(keyword_chars)} end
    )
  end

  # Element Ref

  def elem_ref_value() do
    sequence(
      [
        not_lookahead(literal("#\{")), # Make sure this isn't a set
        ignore(hash()),
        commit(), # Otherwise it MUST be an elem_ref
        js_identifier()
      ],
      label: "elem_ref-value",
      debug: true,
      ast: fn [expr] -> {:elem_ref, expr} end
    )


  end

  # Attr Ref

  def attr_ref_value() do
    sequence(
      [
        ignore(char(?&)),
        js_identifier()
      ],
      label: "ref_value",
      debug: true,
      ast: fn [name] -> {:attr_ref, name} end
    )
  end

  # Function

  def function_value() do
    sequence(
      [
        ignore(open_paren()),
        iows(),
        optional(
          sequence(
            [
              js_identifier(),
              iows(),
              many(
                sequence([
                  ignore(comma()),
                  iows(),
                  js_identifier()
                ])
              )
            ],
            ast: &List.flatten/1
          )
        ),
        ignore(close_paren()),
        iows(),
        ignore(arrow()),
        iows(),
        delimited_text(?{, ?})
      ],
      label: "function-value",
      debug: true,
      ast: fn
        [args, body] ->
          {:function, {args, body}}
        [body] -> {:function, {[], body}}
      end
    )
  end

  # Dice

  def dice_value() do
    sequence([
      optional(number_value()),
      ignore(char(?d)),
      number_value(),
      optional(
        sequence([
          choice([
            char(?+),
            char(?-)
          ]),
          number_value()
        ])
      )
    ],
    label: "dice-value",
    ast: fn
      # d6
      [{:number, sides}] ->
        {:roll, {1, sides, 0}}

      # 2d6
      [{:number, count}, {:number, sides}] ->
        {:roll, {count, sides, 0}}

      # d6+1
      [{:number, sides}, [?+, {:number, mod}]] ->
        {:roll, {1, sides, mod}}

      # d6-1
      [{:number, sides}, [?-, {:number, mod}]] ->
        {:roll, {1, sides, -mod}}

      # 2d6+1
      [{:number, count}, {:number, sides}, [?+, {:number, mod}]] ->
        {:roll, {count, sides, mod}}

      # 2d6-1
      [{:number, count}, {:number, sides}, [?-, {:number, mod}]] ->
        {:roll, {count, sides, -mod}}
    end)
  end

  # String & Function from file

  def map_ext(file_path) do
    case Path.extname(file_path) do
      ".txt" -> :string
      ".html" -> :string
      ".md" -> :string
      ".js" -> :function
      _ -> :unknown
    end
  end

  def read_javascript(raw_js) do
    case Ergo.parse(function_value(), raw_js) do
      %{status: :ok, ast: fun_val} ->
        fun_val

      %{status: {:error, err_info}} ->
        {:error, err_info}
    end
  end

  def read_file_var(file_name) do
    case Path.wildcard("**/#{file_name}") do
      [] -> # No files found
        {:error, "No file found for #{file_name}"}

      [file_path | []] -> # One file found
        case map_ext(file_path) do
          :string ->
            {:string, File.read!(file_path)}

          :function ->
            read_javascript(File.read!(file_path))

          :unknown ->
            {:error, "File #{file_path} doesn't map to an attribute type"}
        end

      _ -> # Multiple files found
        {:error, "Multiple files found for #{file_name}"}
    end
  end

  def file_value() do
    sequence([
      ignore(literal("<<<")),
      commit(),
      many(
        sequence([
          not_lookahead(literal(">>>")),
          any()
        ])),
      ignore(literal(">>>"))
    ],
    label: "file-value",
    ctx: fn ctx ->
      case ctx do
        %{status: :ok, ast: file_name_chars} ->
          file_name = List.to_string(file_name_chars)
          case read_file_var(file_name) do
            {:error, reason} ->
              Context.add_error(ctx, :unknown_file, reason)

            var ->
              Context.set_ast(ctx, var)
          end
      end
    end)
  end

  # Value

  def value() do
    choice(
      [
        dice_value(),
        number_value(),
        bool_value(),
        heredoc_value(),
        string_value(),
        elem_ref_value(),
        keyword_value(),
        function_value(),
        attr_ref_value(),
        file_value(),
      ],
      label: "value",
      debug: true
    )
  end

end
