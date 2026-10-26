defmodule Rez.Parser.JSBlockParser do
  @moduledoc """
  Implements a terminal parser for balanced JavaScript blocks such as a
  function body `{...}` or an array literal `[...]`.

  It replaces Ergo's `delimited_text/2` for JavaScript source for two reasons:

  * Speed: it scans the input binary directly and updates the `Context` once,
    rather than reading a character at a time through `Context.next_char/1`.

  * Correctness: it ignores delimiters inside string literals, template
    literals (including nested `${...}` expressions), comments and regular
    expression literals, so `"}"` or `// }` no longer end a block early.

  Regex literals cannot be told apart from division without fully parsing
  JavaScript, so they are recognised heuristically: a `/` starts a regex when
  the preceding significant character could not end an expression (e.g. `(`,
  `=`, `,` or a keyword such as `return`) and the regex closes on the same
  line. Otherwise the `/` is treated as division.

  Unterminated `'` and `"` strings end at the line break (raw newlines are
  illegal in them) so a stray quote cannot swallow the rest of the block.

  The AST is the block text including its delimiters.
  """

  alias Ergo.{Context, Parser}

  @regex_keywords ~w(return typeof instanceof in of new delete void throw case do else yield await)

  defguardp is_ident_byte(b)
            when b in ?a..?z or b in ?A..?Z or b in ?0..?9 or b == ?_ or b == ?$ or b >= 0x80

  defguardp is_ws_byte(b) when b in [?\s, ?\t, ?\n, ?\r, ?\v, ?\f]

  def js_block(open, close) do
    Parser.terminal(
      :js_block,
      "js_block<#{<<open::utf8>>}#{<<close::utf8>>}>",
      fn ctx -> parse_block(ctx, open, close) end
    )
  end

  defp parse_block(%Context{input: <<c, rest::binary>> = input} = ctx, open, close)
       when c == open do
    case code(rest, input, 1, 1, open, close) do
      {:ok, _rest, len} ->
        <<block::binary-size(len), remaining::binary>> = input
        advance(ctx, block, remaining)

      :eoi ->
        Context.add_error(
          ctx,
          :unterminated_block,
          "No matching '#{<<close::utf8>>}' for '#{<<open::utf8>>}' opened here"
        )
    end
  end

  defp parse_block(%Context{input: ""} = ctx, _open, _close) do
    Context.add_error(ctx, :unexpected_eoi, "Unexpected end of input")
  end

  defp parse_block(%Context{input: input} = ctx, open, _close) do
    Context.add_error(
      ctx,
      :unexpected_char,
      "Expected: |#{<<open::utf8>>}| Actual: |#{String.first(input)}|"
    )
  end

  # Moves the context past the block in one step. index and col count
  # codepoints to match Context.next_char/1.
  defp advance(%Context{index: index, line: line, col: col} = ctx, block, remaining) do
    {new_line, new_col} =
      case :binary.matches(block, "\n") do
        [] ->
          {line, col + codepoints(block)}

        newlines ->
          {last_nl, 1} = List.last(newlines)
          tail = binary_part(block, last_nl + 1, byte_size(block) - last_nl - 1)
          {line + length(newlines), 1 + codepoints(tail)}
      end

    %{
      ctx
      | status: :ok,
        ast: block,
        input: remaining,
        index: index + codepoints(block),
        line: new_line,
        col: new_col
    }
  end

  # Counts UTF-8 codepoints by skipping continuation bytes
  defp codepoints(bin) do
    for <<b <- bin>>, b < 0x80 or b >= 0xC0, reduce: 0, do: (n -> n + 1)
  end

  # ---------------------------------------------------------------------------
  # Scanners
  #
  # Each scanner walks the remaining binary while tracking `pos`, the byte
  # offset into `all` (the input starting at the opening delimiter). They
  # return {:ok, rest, pos} with rest/pos just past what they consumed, or
  # :eoi if the input ran out. Every delimiter is ASCII so scanning bytes is
  # safe for UTF-8 input.
  # ---------------------------------------------------------------------------

  defp code(<<c, rest::binary>>, all, pos, depth, open, close) when c == close do
    case depth do
      1 -> {:ok, rest, pos + 1}
      _ -> code(rest, all, pos + 1, depth - 1, open, close)
    end
  end

  defp code(<<c, rest::binary>>, all, pos, depth, open, close) when c == open do
    code(rest, all, pos + 1, depth + 1, open, close)
  end

  defp code(<<q, rest::binary>>, all, pos, depth, open, close) when q in [?", ?'] do
    with {:ok, rest, pos} <- quoted(rest, pos + 1, q) do
      code(rest, all, pos, depth, open, close)
    end
  end

  defp code(<<?`, rest::binary>>, all, pos, depth, open, close) do
    with {:ok, rest, pos} <- template(rest, all, pos + 1) do
      code(rest, all, pos, depth, open, close)
    end
  end

  defp code(<<"//", rest::binary>>, all, pos, depth, open, close) do
    case :binary.match(rest, "\n") do
      {nl, 1} ->
        skip = nl + 1

        code(
          binary_part(rest, skip, byte_size(rest) - skip),
          all,
          pos + 2 + skip,
          depth,
          open,
          close
        )

      :nomatch ->
        :eoi
    end
  end

  defp code(<<"/*", rest::binary>>, all, pos, depth, open, close) do
    case :binary.match(rest, "*/") do
      {end_at, 2} ->
        skip = end_at + 2

        code(
          binary_part(rest, skip, byte_size(rest) - skip),
          all,
          pos + 2 + skip,
          depth,
          open,
          close
        )

      :nomatch ->
        :eoi
    end
  end

  defp code(<<?/, rest::binary>>, all, pos, depth, open, close) do
    with true <- regex_allowed?(all, pos - 1),
         {:ok, rest, pos} <- regex(rest, pos + 1, false) do
      code(rest, all, pos, depth, open, close)
    else
      _division -> code(rest, all, pos + 1, depth, open, close)
    end
  end

  defp code(<<_, rest::binary>>, all, pos, depth, open, close) do
    code(rest, all, pos + 1, depth, open, close)
  end

  defp code(<<>>, _all, _pos, _depth, _open, _close), do: :eoi

  # '...' and "..." strings
  defp quoted(<<?\\, _, rest::binary>>, pos, q), do: quoted(rest, pos + 2, q)
  defp quoted(<<q, rest::binary>>, pos, q), do: {:ok, rest, pos + 1}
  defp quoted(<<?\n, _::binary>> = rest, pos, _q), do: {:ok, rest, pos}
  defp quoted(<<_, rest::binary>>, pos, q), do: quoted(rest, pos + 1, q)
  defp quoted(<<>>, _pos, _q), do: :eoi

  # `...` template literals; ${...} expressions are code with their own braces
  defp template(<<?\\, _, rest::binary>>, all, pos), do: template(rest, all, pos + 2)
  defp template(<<?`, rest::binary>>, _all, pos), do: {:ok, rest, pos + 1}

  defp template(<<"${", rest::binary>>, all, pos) do
    with {:ok, rest, pos} <- code(rest, all, pos + 2, 1, ?{, ?}) do
      template(rest, all, pos)
    end
  end

  defp template(<<_, rest::binary>>, all, pos), do: template(rest, all, pos + 1)
  defp template(<<>>, _all, _pos), do: :eoi

  # /.../ regex body; a `/` inside a [...] class does not end it. Reaching a
  # line break or the end of input means this was not a regex after all.
  defp regex(<<?\\, c, _::binary>>, _pos, _in_class) when c in [?\n, ?\r], do: :not_regex
  defp regex(<<?\\, _, rest::binary>>, pos, in_class), do: regex(rest, pos + 2, in_class)
  defp regex(<<?[, rest::binary>>, pos, _in_class), do: regex(rest, pos + 1, true)
  defp regex(<<?], rest::binary>>, pos, _in_class), do: regex(rest, pos + 1, false)
  defp regex(<<?/, rest::binary>>, pos, false), do: {:ok, rest, pos + 1}
  defp regex(<<c, _::binary>>, _pos, _in_class) when c in [?\n, ?\r], do: :not_regex
  defp regex(<<_, rest::binary>>, pos, in_class), do: regex(rest, pos + 1, in_class)
  defp regex(<<>>, _pos, _in_class), do: :not_regex

  # Looks back from byte offset `i` past whitespace: a `/` can start a regex
  # unless the previous token could end an expression (identifier, number,
  # closing bracket or string).
  defp regex_allowed?(all, i) do
    case :binary.at(all, i) do
      b when is_ws_byte(b) -> regex_allowed?(all, i - 1)
      b when is_ident_byte(b) -> previous_word(all, i, i) in @regex_keywords
      b when b in [?), ?], ?", ?', ?`, ?.] -> false
      _ -> true
    end
  end

  defp previous_word(all, i, last) when i > 0 do
    case :binary.at(all, i - 1) do
      b when is_ident_byte(b) -> previous_word(all, i - 1, last)
      _ -> binary_part(all, i, last - i + 1)
    end
  end

  defp previous_word(all, 0, last), do: binary_part(all, 0, last + 1)
end
