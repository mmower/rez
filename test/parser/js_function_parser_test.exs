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
end
