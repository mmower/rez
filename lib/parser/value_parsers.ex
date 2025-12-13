defmodule Rez.Parser.ValueParsers do
  @moduledoc """
  Defines the parses to parse non-collection values such as strings, booleans,
  keywords, functions, templates, etc…
  """
  alias Ergo.Context

  import Ergo.Combinators
  import Ergo.Terminals
  import Ergo.Numeric
  import Ergo.Meta

  import Rez.Utils

  import Rez.Parser.ParserCache, only: [cached_parser: 1]

  import Rez.Parser.DefaultParser
  import Rez.Parser.IdentifierParser
  import Rez.Parser.UtilityParsers
  import Rez.Parser.DelimitedParser

  # String

  def string_err_wrap(%Context{status: {:error, :unexpected_character}} = ctx) do
    %{ctx | status: {:error, :string_error}}
  end

  def string_err_wrap(context) do
    context
  end

  def string_value() do
    cached_parser(
      sequence(
        [
          not_lookahead(literal("\"\"\"")),
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
      fn line -> String.replace_prefix(line, leading_match, "") end
    )
  end

  def convert_doc_fragments_to_string(chars) when is_list(chars) do
    chars
    |> List.to_string()
    |> convert_doc_fragments_to_string()
  end

  def convert_doc_fragments_to_string(s) when is_binary(s) do
    s
    |> trim_leading_carriage_return()
    |> trim_tailing_carriage_return()
    |> trim_leading_space()
  end

  @doc ~S"""
  template_value() parses ```template source``` into a {:source_template, "<function source>"}
  """
  def template_value() do
    cached_parser(
      Rez.Parser.DelimitedParser.text_delimited_by_parsers(literal("```"), literal("```"))
      |> transform(&convert_doc_fragments_to_string/1)
      |> transform(fn template_source ->
        {:source_template, template_source}
      end)
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
    cached_parser(
      choice(
        [
          choice([literal("true"), literal("yes")]) |> transform(fn _ -> {:boolean, true} end),
          choice([literal("false"), literal("no")]) |> transform(fn _ -> {:boolean, false} end)
        ],
        label: "boolean-value",
        debug: true
      )
    )
  end

  # Number

  def number_value() do
    cached_parser(number() |> transform(fn number -> {:number, number} end))
  end

  # Keyword

  def keyword_value() do
    cached_parser(
      sequence(
        [
          ignore(colon()),
          many(char([?_, ?$, [?a..?z], [?A..?Z], [?0..?9]], label: "kw_char"), min: 1)
        ],
        label: "keyword-value",
        debug: true,
        ast: fn [keyword_chars] -> {:keyword, List.to_string(keyword_chars)} end
      )
    )
  end

  # Element Ref
  # #elem_id

  def elem_ref_value() do
    set_start_parser = literal("#\{")

    cached_parser(
      sequence(
        [
          # Make sure this isn't a set
          not_lookahead(set_start_parser),
          ignore(hash()),
          # Otherwise it MUST be an elem_ref
          commit(),
          # optional(bang()),
          js_identifier()
        ],
        label: "elem-ref-value",
        debug: true,
        ast: fn
          [elem_id] ->
            {:elem_ref, elem_id}
            # [_bang, elem_id] -> {:clone_ref, elem_id}
        end
      )
    )
  end

  def priority() do
    cached_parser(
      optional(
        sequence(
          [
            ignore(colon()),
            number()
          ],
          ast: fn [prio] -> prio end
        )
      )
      |> default(10)
    )
  end

  # Copy initializer
  # ^c:#elem_id or ^c:N:#elem_id where N is priority 1-10
  def copy_initializer_value() do
    cached_parser(
      sequence(
        [
          ignore(caret()),
          ignore(char(?c)),
          commit(),
          priority(),
          ignore(colon()),
          elem_ref_value()
        ],
        label: "copy-initializer (^c:#id)",
        ast: fn [prio, {:elem_ref, elem_id}] ->
          {:copy_initializer, {elem_id, bounded(prio, 1, 10)}}
        end
      )
    )
  end

  # Delegate
  # ^d:<attr-name> where attr-name specifies an attribute that holds a reference to another element.
  # Creates a property that delegates to the corresponding property of the referenced element.
  # E.g. hull_id: #foo, purpose: ^d:hull will create a purpose property that reads from foo.purpose
  def delegate_value() do
    cached_parser(
      sequence(
        [
          ignore(caret()),
          ignore(char(?d)),
          commit(),
          ignore(colon()),
          js_identifier("delegate_attr")
        ],
        label: "delegate (^d:<attr-name>)",
        ast: fn [attr_name] ->
          {:delegate, attr_name}
        end
      )
    )
  end

  # Dynamic Initializer
  # ^i{...}
  def dynamic_initializer_value() do
    cached_parser(
      sequence(
        [
          ignore(caret()),
          ignore(char(?i)),
          priority(),
          text_delimited_by_nested_parsers(open_brace(), close_brace())
        ],
        ast: fn
          [prio, initializer] -> {:dynamic_initializer, {initializer, bounded(prio, 1, 10)}}
        end
      )
    )
  end

  def code_block_value() do
    cached_parser(
      sequence(
        [
          lookahead(sequence([caret(), open_brace()])),
          ignore(caret()),
          text_delimited_by_nested_parsers(open_brace(), close_brace())
        ],
        ast: fn [code] -> {:code_block, code} end
      )
    )
  end

  # Property
  # ^p{}
  def property_value() do
    cached_parser(
      sequence(
        [
          ignore(caret()),
          ignore(char(?p)),
          text_delimited_by_nested_parsers(open_brace(), close_brace())
        ],
        ast: fn [f] -> {:property, f} end
      )
    )
  end

  # Function
  # function(...) {...}
  def traditional_function_value() do
    cached_parser(
      sequence(
        [
          ignore(literal("function")),
          iows(),
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
          delimited_text(?{, ?})
        ],
        label: "function-value",
        debug: true,
        ast: fn
          [args, body] ->
            {:function, {:std, args, body}}

          [body] ->
            {:function, {:std, [], body}}
        end
      )
    )
  end

  # Arrow function
  # (...) => {...}
  def arrow_function_value() do
    cached_parser(
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
            {:function, {:arrow, args, body}}

          [body] ->
            {:function, {:arrow, [], body}}
        end
      )
    )
  end

  def function_value() do
    cached_parser(
      choice([
        traditional_function_value(),
        arrow_function_value()
      ])
    )
  end

  # Dice
  # ndX+-m
  # 2d+6, 3d8-2, 1d10+1
  def dice_value() do
    cached_parser(
      sequence(
        [
          ignore(caret()),
          ignore(char(?r)),
          ignore(colon()),
          optional(number_value()) |> default({:number, 1}),
          ignore(char(?d)),
          number_value(),
          optional(
            sequence(
              [
                choice([
                  plus(),
                  minus()
                ]),
                number_value()
              ],
              ast: fn [op, {:number, mod}] ->
                case op do
                  ?+ -> {:number, mod}
                  ?- -> {:number, -mod}
                end
              end
            )
          )
          |> default({:number, 0}),
          optional(
            sequence(
              [
                ignore(colon()),
                number_value()
              ],
              ast: fn [rounds] ->
                {:number, rounds}
              end
            )
          )
          |> default({:number, 1})
        ],
        label: "dice-value",
        ast: fn [{:number, count}, {:number, sides}, {:number, mod}, {:number, rounds}] ->
          {:roll, {count, sides, mod, rounds}}
        end
      )
    )
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
      # No files found
      [] ->
        {:error, "No file found for #{file_name}"}

      # One file found
      [file_path | []] ->
        case map_ext(file_path) do
          :string ->
            {:string, File.read!(file_path)}

          :function ->
            read_javascript(File.read!(file_path))

          :unknown ->
            {:error, "File #{file_path} doesn't map to an attribute type"}
        end

      # Multiple files found
      _ ->
        {:error, "Multiple files found for #{file_name}"}
    end
  end

  def file_value() do
    open = literal("<<<")
    close = literal(">>>")

    cached_parser(
      sequence(
        [
          ignore(open),
          commit(),
          many(
            sequence([
              not_lookahead(close),
              any()
            ])
          ),
          ignore(close)
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
        end
      )
    )
  end

  def placeholder_value() do
    cached_parser(char(?_) |> replace({:placeholder, nil}))
  end

  # Constant Reference
  # $const_name

  def const_ref_value() do
    cached_parser(
      sequence(
        [
          ignore(char(?$)),
          commit(),
          js_identifier()
        ],
        label: "const-ref-value",
        debug: true,
        ast: fn [const_name] ->
          {:const_ref, const_name}
        end
      )
    )
  end

  # Value

  def simple_value() do
    cached_parser(
      choice([
        bool_value(),
        number_value(),
        string_value()
      ])
    )
  end

  def value() do
    cached_parser(
      choice(
        [
          bool_value(),
          number_value(),
          string_value(),
          keyword_value(),
          template_value(),
          function_value(),
          property_value(),
          dice_value(),
          elem_ref_value(),
          const_ref_value(),
          dynamic_initializer_value(),
          copy_initializer_value(),
          delegate_value(),
          file_value(),
          placeholder_value()
        ],
        label: "value",
        debug: true
      )
    )
  end
end
