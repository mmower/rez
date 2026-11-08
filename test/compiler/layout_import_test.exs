defmodule Rez.Compiler.LayoutImportTest do
  use ExUnit.Case

  alias Rez.AST.{Attribute, Game, Layout, Scene}
  alias Rez.Compiler.Compilation
  alias Rez.Compiler.Phases.ApplyDefaults

  defp attrs(list), do: Map.new(list, &{&1.name, &1})

  defp binding(prefix, ref), do: {:list_binding, {prefix, {:source, false, {:elem_ref, ref}}}}

  defp layout(id, attr_list), do: %Layout{id: id, attributes: attrs(attr_list)}

  defp scene(id, attr_list, alias_chain \\ ["scene"]) do
    %Scene{id: id, attributes: attrs(attr_list), metadata: %{"alias_chain" => alias_chain}}
  end

  defp game(attr_list) do
    %Game{attributes: attrs(attr_list), metadata: %{"alias_chain" => ["game"]}}
  end

  defp run(content, defaults \\ %{}) do
    ApplyDefaults.run_phase(%Compilation{status: :ok, content: content, defaults: defaults})
  end

  defp node(%Compilation{content: content}, id), do: Enum.find(content, &(&1.id == id))

  defp prefixes(%Attribute{value: list}),
    do: Enum.map(list, fn {:list_binding, {prefix, {:source, _, {:elem_ref, ref}}}} -> {prefix, ref} end)

  @two_col %Layout{
             id: "l_two",
             attributes: %{
               "layout" => Attribute.source_template("layout", "<div>${content}</div>"),
               "layout_mode" => Attribute.keyword("layout_mode", "stack"),
               "layout_separator" => Attribute.string("layout_separator", "<hr/>")
             }
           }

  describe "importing a layout into a scene" do
    test "imports layout attributes and replaces layout_id with $layout_reference" do
      s = scene("s_a", [Attribute.elem_ref("layout_id", "l_two")])
      compilation = run([@two_col, s])

      assert compilation.status == :ok
      s = node(compilation, "s_a")
      assert %Attribute{type: :source_template, value: "<div>${content}</div>"} = s.attributes["layout"]
      assert %Attribute{value: "stack"} = s.attributes["layout_mode"]
      assert %Attribute{type: :string, value: "l_two"} = s.attributes["$layout_reference"]
      refute Map.has_key?(s.attributes, "layout_id")
    end

    test "precedence is defaults, then layout, then the scene itself" do
      defaults = %{
        "scene" => attrs([
          Attribute.keyword("layout_mode", "single"),
          Attribute.string("layout_separator", ""),
          Attribute.boolean("layout_reverse", false)
        ])
      }

      s = scene("s_a", [Attribute.elem_ref("layout_id", "l_two"), Attribute.string("layout_separator", "<br/>")])
      s = node(run([@two_col, s], defaults), "s_a")

      # from the scene itself
      assert s.attributes["layout_separator"].value == "<br/>"
      # layout beats defaults
      assert s.attributes["layout_mode"].value == "stack"
      # defaults still apply where the layout is silent
      assert s.attributes["layout_reverse"].value == false
    end

    test "layout_id can come from @defaults" do
      defaults = %{"scene" => attrs([Attribute.elem_ref("layout_id", "l_two")])}
      s = node(run([@two_col, scene("s_a", [])], defaults), "s_a")

      assert s.attributes["layout_mode"].value == "stack"
      assert s.attributes["$layout_reference"].value == "l_two"
      refute Map.has_key?(s.attributes, "layout_id")
    end

    test "handlers chain defaults -> layout -> scene and imported handlers are tagged from_defaults" do
      defaults = %{"scene" => attrs([Attribute.arrow_function("on_did_render", {["o", "e"], "{base();}"})])}

      l =
        layout("l_r", [
          Attribute.source_template("layout", "${content}"),
          Attribute.append_function("on_did_render", {:arrow, ["o", "e"], "{layout();}"}),
          Attribute.arrow_function("on_will_render", {["o", "e"], "{will();}"})
        ])

      s =
        scene("s_a", [
          Attribute.elem_ref("layout_id", "l_r"),
          Attribute.append_function("on_did_render", {:arrow, ["o", "e"], "{scene();}"})
        ])

      s = node(run([l, s], defaults), "s_a")

      %Attribute{type: :function, value: {:arrow, _, body}} = s.attributes["on_did_render"]
      {base, _} = :binary.match(body, "base();")
      {lay, _} = :binary.match(body, "layout();")
      {sc, _} = :binary.match(body, "scene();")
      assert base < lay and lay < sc

      assert s.attributes["on_will_render"].from_defaults
      refute s.attributes["on_did_render"].from_defaults
    end

    test "bindings merge with layout entries first and same-prefix entries replaced in place" do
      l =
        layout("l_b", [
          Attribute.source_template("layout", "${content}"),
          Attribute.list("bindings", [binding("a", "x1"), binding("b", "x2")])
        ])

      s =
        scene("s_a", [
          Attribute.elem_ref("layout_id", "l_b"),
          Attribute.list("bindings", [binding("c", "y1"), binding("a", "y2")])
        ])

      s = node(run([l, s]), "s_a")
      assert prefixes(s.attributes["bindings"]) == [{"a", "y2"}, {"b", "x2"}, {"c", "y1"}]
    end

    test "a scene without bindings gets the layout's bindings" do
      l =
        layout("l_b", [
          Attribute.source_template("layout", "${content}"),
          Attribute.list("blocks", [binding("side", "c_side")])
        ])

      s = node(run([l, scene("s_a", [Attribute.elem_ref("layout_id", "l_b")])]), "s_a")
      assert prefixes(s.attributes["blocks"]) == [{"side", "c_side"}]
    end
  end

  describe "importing a layout into the game" do
    test "a single layout is imported without stack attributes" do
      l =
        layout("l_main", [
          Attribute.source_template("layout", "<main>${content}</main>"),
          Attribute.keyword("layout_mode", "single"),
          Attribute.string("layout_separator", "<hr/>")
        ])

      compilation = run([l, game([Attribute.elem_ref("layout_id", "l_main")])])
      assert compilation.status == :ok

      g = node(compilation, "game")
      assert g.attributes["layout"].value == "<main>${content}</main>"
      assert g.attributes["$layout_reference"].value == "l_main"
      refute Map.has_key?(g.attributes, "layout_separator")
      refute Map.has_key?(g.attributes, "layout_mode")
    end

    test "a stack layout is an error" do
      compilation = run([@two_col, game([Attribute.elem_ref("layout_id", "l_two")])])

      assert compilation.status == :error
      assert [error] = compilation.errors
      assert error =~ "@game can only use a single layout"
      assert error =~ "l_two"
    end
  end

  describe "errors" do
    test "unknown layout" do
      compilation = run([scene("s_a", [Attribute.elem_ref("layout_id", "l_missing")])])

      assert compilation.status == :error
      assert [error] = compilation.errors
      assert error =~ "unknown @layout #l_missing"
    end

    test "layout_id must be a literal element reference" do
      compilation = run([@two_col, scene("s_a", [Attribute.const_ref("layout_id", "L")])])

      assert compilation.status == :error
      assert [error] = compilation.errors
      assert error =~ "literal element reference"
    end

    test "nested layouts are not supported" do
      l =
        layout("l_nested", [
          Attribute.source_template("layout", "${content}"),
          Attribute.elem_ref("layout_id", "l_two")
        ])

      compilation = run([@two_col, l])

      assert compilation.status == :error
      assert [error] = compilation.errors
      assert error =~ "nested layouts are not supported"
    end

    test "attributes that aren't layout attributes are not allowed" do
      l =
        layout("l_bad", [
          Attribute.source_template("layout", "${content}"),
          Attribute.string("title", "Nope")
        ])

      compilation = run([l])

      assert compilation.status == :error
      assert [error] = compilation.errors
      assert error =~ "title not allowed in a @layout"
    end
  end
end
