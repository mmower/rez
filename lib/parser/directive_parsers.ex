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

  import Rez.Utils, only: [attr_list_to_map: 1]

  defp behaviour_template() do
    sequence(
      [
        iliteral("@behaviour_template"),
        iws(),
        commit(),
        js_identifier("behaviour_template"),
        iws(),
        bt_parser()
      ],
      label: "@behaviour_template",
      ast: fn [template_id, {:bht, bht}] ->
        {:behaviour_template, template_id, bht}
      end
    )
  end

  defp component_directive() do
    sequence(
      [
        iliteral("@component"),
        iws(),
        js_identifier("name"),
        iws(),
        arrow_function_value()
      ],
      label: "@component",
      ast: fn [name, impl_fn] ->
        {:user_component, name, impl_fn}
      end
    )
  end

  defp declare_directive() do
    sequence(
      [
        iliteral("@declare"),
        iws(),
        commit(),
        js_identifier("declare")
      ],
      label: "@declare",
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

  defp defaults_directive() do
    sequence(
      [
        iliteral("@defaults"),
        iws(),
        commit(),
        elem_tag(),
        iws(),
        block_begin(),
        attribute_list(),
        iws(),
        block_end()
      ],
      label: "@defaults",
      ast: fn [elem, attributes] ->
        {:defaults, elem, attr_list_to_map(attributes)}
      end
    )
  end

  defp derive_directive() do
    sequence(
      [
        iliteral("@derive"),
        iws(),
        commit(),
        keyword_value(),
        iws(),
        keyword_value()
      ],
      label: "@derive",
      ast: fn [{:keyword, tag}, {:keyword, parent}] ->
        {:derive, tag, parent}
      end
    )
  end

  defp enum_directive() do
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
      label: "@enum",
      ast: fn [id, first_kw, other_kws] ->
        {:enum, id, [first_kw | List.flatten(other_kws)]}
      end
    )
  end

  defp modifier_key(modifier_name, event_name) do
    sequence([
      iliteral(modifier_name),
      iows(),
      plus(),
      iows()
    ])
    |> replace(event_name)
  end

  defp keyboard_modifier() do
    choice([
      modifier_key("shift", :shiftKey),
      modifier_key("meta", :metaKey),
      modifier_key("ctrl", :ctrlKey),
      modifier_key("alt", :altKey)
    ])
  end

  defp keyboard_modifiers() do
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

  defp key_name() do
    sequence([
      alpha(),
      many(choice([alpha(), digit()]))
    ])
    |> transform(fn ast -> ast |> List.flatten() |> List.to_string() end)
  end

  defp key_desc() do
    sequence(
      [
        keyboard_modifiers(),
        key_name()
      ],
      ast: fn [modifiers, key] -> {:keybinding, modifiers, key} end
    )
  end

  defp keybinding_directive() do
    sequence(
      [
        iliteral("@keybinding"),
        iws(),
        commit(),
        key_desc(),
        iws(),
        keyword_value()
      ],
      label: "@keybinding",
      ast: fn [{:keybinding, modifiers, key}, event] ->
        {:keybinding, modifiers, key, event}
      end
    )
  end

  def directive() do
    choice(
      [
        behaviour_template(),
        component_directive(),
        declare_directive(),
        defaults_directive(),
        derive_directive(),
        enum_directive(),
        keybinding_directive()
      ],
      label: "directive"
    )
  end
end
