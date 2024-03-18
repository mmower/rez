defmodule Rez.Parser.DirectiveParsers do
  alias Ergo.Context

  import Ergo.Combinators
  import Ergo.Terminals
  import Ergo.Meta

  import Rez.Parser.StructureParsers
  import Rez.Parser.UtilityParsers
  import Rez.Parser.ValueParsers
  import Rez.Parser.IdentifierParser
  import Rez.Parser.BTreeParser

  def behaviour_template() do
    sequence(
      [
        iliteral("@behaviour_template"),
        iws(),
        commit(),
        js_identifier("behaviour_template"),
        iws(),
        bt_parser()
      ],
      ast: fn [template_id, {:bht, bht}] ->
        {:behaviour_template, template_id, bht}
      end
    )
  end

  def declare_directive() do
    sequence(
      [
        iliteral("@declare"),
        iws(),
        commit(),
        js_identifier("declare")
      ],
      label: "declare",
      ctx: fn %Context{
                entry_points: [{line, col} | _],
                ast: [id],
                data: %{source: source}
              } = ctx ->
        {source_file, source_line} = LogicalFile.resolve_line(source, line)

        block =
          create_block(
            Rez.AST.Object,
            id,
            [],
            %{},
            source_file,
            source_line,
            col
          )

        ctx_with_block_and_id_mapped(ctx, block, id, "declare", source_file, source_line)
      end
    )
  end

  def derive_directive() do
    sequence(
      [
        iliteral("@derive"),
        iws(),
        commit(),
        keyword_value(),
        iws(),
        keyword_value()
      ],
      label: "derive",
      ast: fn [{:keyword, tag}, {:keyword, parent}] ->
        {:derive, tag, parent}
      end
    )
  end

  def enum_directive() do
    sequence(
      [
        iliteral("@enum"),
        iws(),
        commit(),
        js_identifier("enum"),
        iws(),
        ignore(open_bracket()),
        keyword_value() |> transform(fn {:keyword, keyword} -> keyword end),
        many(
          sequence([
            iws(),
            keyword_value() |> transform(fn {:keyword, keyword} -> keyword end)
          ])
        ),
        iows(),
        ignore(close_bracket())
      ],
      label: "enum",
      ast: fn [id, first_kw, other_kws] ->
        {:enum, id, [first_kw | List.flatten(other_kws)]}
      end
    )
  end

  def modifier_key(modifier_name, event_name) do
    sequence([
      iliteral(modifier_name),
      iows(),
      plus(),
      iows()
    ])
    |> replace(event_name)
  end

  def keyboard_modifier() do
    choice([
      modifier_key("shift", :shiftKey),
      modifier_key("meta", :metaKey),
      modifier_key("ctrl", :ctrlKey),
      modifier_key("alt", :altKey)
    ])
  end

  def keyboard_modifiers() do
    many(keyboard_modifier())
    |> transform(fn modifier_list ->
      {:modifiers,
       Enum.reduce(
         modifier_list,
         %{shiftKey: false, altKey: false, metaKey: false, ctrlKey: false},
         fn key_mod, modifiers ->
           Map.put(modifiers, key_mod, true)
         end
       )}
    end)
  end

  def key_name() do
    sequence([
      alpha(),
      many(choice([alpha(), digit()]))
    ])
    |> transform(fn ast -> ast |> List.flatten() |> List.to_string() end)
  end

  def key_desc() do
    sequence(
      [
        keyboard_modifiers(),
        key_name()
      ],
      ast: fn [modifiers, key] -> {:keybinding, modifiers, key} end
    )
  end

  def keybinding_directive() do
    sequence(
      [
        iliteral("@keybinding"),
        iws(),
        commit(),
        key_desc(),
        iws(),
        keyword_value()
      ],
      label: "keybinding",
      ast: fn [{:keybinding, modifiers, key}, event] ->
        {:keybinding, modifiers, key, event}
      end
    )
  end
end
