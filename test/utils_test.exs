defmodule UtilsTest do
  use ExUnit.Case
  doctest Rez.Utils

  test "double encoding double quotes" do
    s = "\"Foo\""

    assert "\\\"Foo\\\"" = Rez.Utils.encode_double_quotes(s)
  end
end
