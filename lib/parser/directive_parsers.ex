defmodule Rez.Parser.DirectiveParsers do
  @moduledoc """
  Defines the parsers that parse special directives such as @component and
  @key_binding which don't follow the normal element rules.
  """
  import Ergo.Combinators
  import Ergo.Terminals
  import Ergo.Meta
  alias Ergo.Context

  import Rez.Parser.CollectionParser, only: [collection: 0]
  import Rez.Parser.StructureParsers
  import Rez.Parser.UtilityParsers
  import Rez.Parser.ValueParsers
  import Rez.Parser.IdentifierParser
  import Rez.Parser.BTreeParser
  import Rez.Parser.ParserTools
  import Rez.Parser.SchemaParser, only: [schema_directive: 0]
  import Rez.Utils, only: [attr_list_to_map: 1]

  defp behaviour_template_directive() do
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
      ctx: fn %Context{ast: [template_id, {:bht, template}]} = ctx ->
        %{
          ctx
          | ast: %Rez.AST.BehaviourTemplate{
              id: template_id,
              position: resolve_position(ctx),
              template: template
            }
        }
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
      ctx: fn %Context{ast: [name, impl_fn]} = ctx ->
        %{
          ctx
          | ast: %Rez.AST.Component{
              position: resolve_position(ctx),
              name: name,
              impl_fn: impl_fn
            }
        }
      end
    )
  end

  defp const_directive() do
    sequence(
      [
        iliteral("@const"),
        iws(),
        commit(),
        js_identifier("const_name"),
        iws(),
        ignore(equals()),
        iws(),
        choice([
          collection(),
          value()
        ])
      ],
      label: "@const",
      ctx: fn %Context{ast: [name, value]} = ctx ->
        {value_type, _} = value

        %{
          ctx
          | ast: %Rez.AST.Const{
              position: resolve_position(ctx),
              name: name,
              value: value,
              value_type: value_type
            }
        }
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
      ctx: fn %Context{ast: [elem, attributes]} = ctx ->
        %{
          ctx
          | ast: %Rez.AST.Defaults{
              position: resolve_position(ctx),
              elem: elem,
              attributes: attr_list_to_map(attributes)
            }
        }
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
      ctx: fn %Context{ast: [{:keyword, tag}, {:keyword, parent}]} = ctx ->
        %{
          ctx
          | ast: %Rez.AST.Derive{
              position: resolve_position(ctx),
              tag: tag,
              parent: parent
            }
        }
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
      Enum.reduce(
        modifier_list,
        %{shiftKey: false, altKey: false, metaKey: false, ctrlKey: false},
        fn key_mod, modifiers ->
          Map.put(modifiers, key_mod, true)
        end
      )
    end)
  end

  defp key_name() do
    sequence([
      alpha(),
      many(choice([alpha(), digit()]))
    ])
    |> transform(fn ast -> ast |> List.flatten() |> List.to_string() end)
    |> transform(fn
      "space" -> " "
      key_name -> key_name
    end)
  end

  defp key_desc() do
    sequence(
      [
        keyboard_modifiers(),
        key_name()
      ],
      ast: fn [modifiers, key] -> {modifiers, key} end
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
      ctx: fn %Context{ast: [{modifiers, key}, {:keyword, event}]} = ctx ->
        %{
          ctx
          | ast: %Rez.AST.KeyBinding{
              position: resolve_position(ctx),
              key: key,
              modifiers: modifiers,
              event: event
            }
        }
      end
    )
  end

  def directive() do
    choice(
      [
        behaviour_template_directive(),
        component_directive(),
        const_directive(),
        # declare_directive(),
        defaults_directive(),
        derive_directive(),
        # enum_directive(),
        keybinding_directive(),
        schema_directive()
      ],
      label: "directive"
    )
  end
end
