defmodule Rez.Parser.JSFunctionParserTest do
  use ExUnit.Case

  alias Ergo.Context
  import Rez.Parser.JSFunctionParser

  # ---------------------------------------------------------------------------
  # Backward compatibility — simple identifiers
  # ---------------------------------------------------------------------------

  describe "backward compatibility" do
    test "traditional function with params" do
      input = "function(x, y) {return x + y;}"

      assert %Context{status: :ok, ast: {:function, {:std, ["x", "y"], "{return x + y;}"}}} =
               Ergo.parse(js_function(), input)
    end

    test "arrow function with params" do
      input = "(x, y) => {return x + y;}"

      assert %Context{status: :ok, ast: {:function, {:arrow, ["x", "y"], "{return x + y;}"}}} =
               Ergo.parse(js_function(), input)
    end

    test "traditional function with no params" do
      input = "function() {return 1;}"

      assert %Context{status: :ok, ast: {:function, {:std, [], "{return 1;}"}}} =
               Ergo.parse(js_function(), input)
    end

    test "arrow function with no params" do
      input = "() => {return 1;}"

      assert %Context{status: :ok, ast: {:function, {:arrow, [], "{return 1;}"}}} =
               Ergo.parse(js_function(), input)
    end
  end

  # ---------------------------------------------------------------------------
  # Default values
  # ---------------------------------------------------------------------------

  describe "default values" do
    test "number default" do
      input = "function(x = 0) {return x;}"

      assert %Context{status: :ok, ast: {:function, {:std, ["x = 0"], "{return x;}"}}} =
               Ergo.parse(js_function(), input)
    end

    test "mixed params with default" do
      input = "(x, y = 3) => {return x;}"

      assert %Context{status: :ok, ast: {:function, {:arrow, ["x", "y = 3"], "{return x;}"}}} =
               Ergo.parse(js_function(), input)
    end

    test "string default" do
      input = ~s|function(x = "hello") {return x;}|

      assert %Context{
               status: :ok,
               ast: {:function, {:std, [~s|x = "hello"|], "{return x;}"}}
             } = Ergo.parse(js_function(), input)
    end

    test "boolean default" do
      input = "function(x = true) {return x;}"

      assert %Context{status: :ok, ast: {:function, {:std, ["x = true"], "{return x;}"}}} =
               Ergo.parse(js_function(), input)
    end

    test "null default" do
      input = "function(x = null) {return x;}"

      assert %Context{status: :ok, ast: {:function, {:std, ["x = null"], "{return x;}"}}} =
               Ergo.parse(js_function(), input)
    end
  end

  # ---------------------------------------------------------------------------
  # Object destructuring
  # ---------------------------------------------------------------------------

  describe "object destructuring" do
    test "simple object destructuring" do
      input = "function({x, y}) {return x;}"

      assert %Context{status: :ok, ast: {:function, {:std, ["{x, y}"], "{return x;}"}}} =
               Ergo.parse(js_function(), input)
    end

    test "object destructuring with other params" do
      input = "({x, y}, z) => {return x;}"

      assert %Context{
               status: :ok,
               ast: {:function, {:arrow, ["{x, y}", "z"], "{return x;}"}}
             } = Ergo.parse(js_function(), input)
    end

    test "object destructuring with rename" do
      input = "function({x: localX, y: localY}) {return localX;}"

      assert %Context{
               status: :ok,
               ast: {:function, {:std, ["{x: localX, y: localY}"], "{return localX;}"}}
             } = Ergo.parse(js_function(), input)
    end

    test "object destructuring with shorthand defaults" do
      input = "function({x = 1, y = 2}) {return x;}"

      assert %Context{
               status: :ok,
               ast: {:function, {:std, ["{x = 1, y = 2}"], "{return x;}"}}
             } = Ergo.parse(js_function(), input)
    end

    test "object destructuring with default object" do
      input = "({x, y} = {}) => {return x;}"

      assert %Context{
               status: :ok,
               ast: {:function, {:arrow, ["{x, y} = {}"], "{return x;}"}}
             } = Ergo.parse(js_function(), input)
    end
  end

  # ---------------------------------------------------------------------------
  # Array destructuring
  # ---------------------------------------------------------------------------

  describe "array destructuring" do
    test "simple array destructuring" do
      input = "function([a, b]) {return a;}"

      assert %Context{status: :ok, ast: {:function, {:std, ["[a, b]"], "{return a;}"}}} =
               Ergo.parse(js_function(), input)
    end

    test "array destructuring with rest" do
      input = "([first, ...rest]) => {return first;}"

      assert %Context{
               status: :ok,
               ast: {:function, {:arrow, ["[first, ...rest]"], "{return first;}"}}
             } = Ergo.parse(js_function(), input)
    end
  end

  # ---------------------------------------------------------------------------
  # Rest parameters
  # ---------------------------------------------------------------------------

  describe "rest parameters" do
    test "rest param only" do
      input = "function(...args) {return args;}"

      assert %Context{status: :ok, ast: {:function, {:std, ["...args"], "{return args;}"}}} =
               Ergo.parse(js_function(), input)
    end

    test "rest param after regular param" do
      input = "(x, ...rest) => {return rest;}"

      assert %Context{
               status: :ok,
               ast: {:function, {:arrow, ["x", "...rest"], "{return rest;}"}}
             } = Ergo.parse(js_function(), input)
    end
  end

  # ---------------------------------------------------------------------------
  # Append functions
  # ---------------------------------------------------------------------------

  describe "append functions" do
    test "arrow append function" do
      input = "+(obj, evt) => {doSomething();}"

      assert %Context{
               status: :ok,
               ast: {:append_function, {:arrow, ["obj", "evt"], "{doSomething();}"}}
             } = Ergo.parse(js_append_function(), input)
    end

    test "traditional append function" do
      input = "+function(obj, evt) {doSomething();}"

      assert %Context{
               status: :ok,
               ast: {:append_function, {:std, ["obj", "evt"], "{doSomething();}"}}
             } = Ergo.parse(js_append_function(), input)
    end

    test "append function with no params" do
      input = "+() => {doSomething();}"

      assert %Context{
               status: :ok,
               ast: {:append_function, {:arrow, [], "{doSomething();}"}}
             } = Ergo.parse(js_append_function(), input)
    end
  end

  # ---------------------------------------------------------------------------
  # Complex combinations
  # ---------------------------------------------------------------------------

  describe "complex combinations" do
    test "mixed params with destructuring default and rest" do
      input = "function(x, {y, z} = {}, ...rest) {return x;}"

      assert %Context{
               status: :ok,
               ast: {:function, {:std, ["x", "{y, z} = {}", "...rest"], "{return x;}"}}
             } = Ergo.parse(js_function(), input)
    end

    test "object destructuring with defaults and rename plus array destructuring" do
      input = "function({x = 1, y: localY}, [a, b]) {return x;}"

      assert %Context{
               status: :ok,
               ast: {:function, {:std, ["{x = 1, y: localY}", "[a, b]"], "{return x;}"}}
             } = Ergo.parse(js_function(), input)
    end
  end

  # ---------------------------------------------------------------------------
  # Every element form
  # ---------------------------------------------------------------------------

  defp params_of(input) do
    assert %Context{status: :ok, ast: {:function, {_, params, _}}} =
             Ergo.parse(js_function(), input)

    params
  end

  describe "object pattern element forms" do
    test "rename with default" do
      assert ["{x: localX = 1}"] = params_of("function({x: localX = 1}) {}")
    end

    test "rename to nested object pattern" do
      assert ["{weapon: {damage, kind}}"] = params_of("function({weapon: {damage, kind}}) {}")
    end

    test "rename to nested pattern with default" do
      assert ["{opts: {a} = {}}"] = params_of("function({opts: {a} = {}}) {}")
    end

    test "rename to array pattern" do
      assert ["{list: [first, second]}"] = params_of("function({list: [first, second]}) {}")
    end

    test "rest element" do
      assert ["{a, ...others}"] = params_of("function({a, ...others}) {}")
    end

    test "all forms together" do
      assert ["{a, b = 1, c: d, e: f = 2, ...g}"] =
               params_of("function({a, b = 1, c: d, e: f = 2, ...g}) {}")
    end
  end

  describe "array pattern element forms" do
    test "element defaults" do
      assert ["[a = 1, b]"] = params_of("function([a = 1, b]) {}")
    end

    test "nested arrays" do
      assert ["[a, [b, c]]"] = params_of("function([a, [b, c]]) {}")
    end

    test "nested object and array with default" do
      assert ["[{a}, [b = 1]]"] = params_of("function([{a}, [b = 1]]) {}")
    end

    test "nested pattern with default" do
      assert ["[[a] = [], {b} = {}]"] = params_of("function([[a] = [], {b} = {}]) {}")
    end

    test "array pattern param with default" do
      assert ["[a, b] = []"] = params_of("([a, b] = []) => {}")
    end
  end

  describe "default value literals" do
    test "negative number" do
      assert ["x = -1"] = params_of("function(x = -1) {}")
    end

    test "single quoted string" do
      assert ["x = 'hi'"] = params_of("function(x = 'hi') {}")
    end

    test "undefined" do
      assert ["x = undefined"] = params_of("function(x = undefined) {}")
    end

    test "array literal" do
      assert ["x = [1, 2]"] = params_of("function(x = [1, 2]) {}")
    end
  end

  describe "whitespace" do
    test "is normalised around separators" do
      assert ["{x: y = 1, z}", "[a = 2]", "w = 3"] =
               params_of("function( { x : y = 1 , z } , [ a = 2 ] , w = 3 ) {}")
    end

    test "newlines inside patterns" do
      assert ["{a, b: c}"] = params_of("function({\n  a,\n  b: c\n}) {}")
    end
  end

  describe "invalid parameters" do
    for input <- [
          "function({x: }) {}",
          "function({x y}) {}",
          "function({}) {}",
          "function([]) {}",
          "function(x =) {}",
          "function(...) {}",
          "function({...{a}}) {}"
        ] do
      test "rejects #{input}" do
        refute match?(%Context{status: :ok}, Ergo.parse(js_function(), unquote(input)))
      end
    end
  end

  describe "nested patterns" do
    test "deep object nesting" do
      assert ["{a: {b: {c: {d}}}}"] = params_of("function({a: {b: {c: {d}}}}) {}")
    end

    # Before the grammar was left-factored each level of nesting doubled the
    # parse time, so depth 16 took seconds. It should now be roughly linear.
    test "deep nesting parses in linear time" do
      depth = 16
      pattern = String.duplicate("{a: ", depth) <> "x" <> String.duplicate("}", depth)

      {us, params} = :timer.tc(fn -> params_of("function(#{pattern}) {}") end)

      assert [^pattern] = params
      assert us < 500_000
    end
  end
end
