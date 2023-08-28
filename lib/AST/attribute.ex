defmodule Rez.AST.Attribute do
  alias __MODULE__

  @moduledoc """
  `Rez.AST.Attribute` contains the `Attribute` struct that is used to store
  the name, type, and value of an attribute associated with a `Node` type
  such as `Actor` or `Game`.

  Rez supports the following types:

  :number -> (+/- integers and floating point values)
  :string -> double-quoted or Heredoc style
  :boolean -> (true|false or, interchangably, yes|no)
  :function -> arrow-style Javascript function body
  :list -> list of other values seperated by whitespace
  :keyword -> a keyword prefixed by ":"
  :elem_ref -> an id prefixed by "#"
  """

  defstruct name: nil,
            type: nil,
            value: nil

  def create(name, {:boolean, value}), do: boolean(name, value)
  def create(name, {:number, value}), do: number(name, value)
  def create(name, {:string, value}), do: string(name, value)
  def create(name, {:function, {:std, params, body}}), do: std_function(name, {params, body})
  def create(name, {:function, {:arrow, params, body}}), do: arrow_function(name, {params, body})
  def create(name, {:elem_ref, value}), do: elem_ref(name, value)
  def create(name, {:keyword, value}), do: keyword(name, value)
  def create(name, {:list, values}), do: list(name, values)
  def create(name, {:set, values}), do: set(name, values)
  def create(name, {:compiled_template, value}), do: compiled_template(name, value)

  def boolean(name, value) do
    %Attribute{name: name, type: :boolean, value: value}
  end

  def number(name, value) do
    %Attribute{name: name, type: :number, value: value}
  end

  def string(name, value) do
    %Attribute{name: name, type: :string, value: value}
  end

  def std_function(name, {params, body}) do
    %Attribute{name: name, type: :function, value: {:std, params, body}}
  end

  def arrow_function(name, {params, body}) do
    %Attribute{name: name, type: :function, value: {:arrow, params, body}}
  end

  def elem_ref(name, value) do
    %Attribute{name: name, type: :elem_ref, value: value}
  end

  def keyword(name, value) do
    %Attribute{name: name, type: :keyword, value: value}
  end

  def list(name, values) when is_list(values) do
    %Attribute{name: name, type: :list, value: values}
  end

  def set(name, values) when is_list(values) do
    %Attribute{name: name, type: :set, value: MapSet.new(values)}
  end

  def set(name, values) do
    %Attribute{name: name, type: :set, value: values}
  end

  def compiled_template(name, value) when is_binary(value) do
    %Attribute{name: name, type: :compiled_template, value: value}
  end

  def is_elem_ref?(%Attribute{type: :elem_ref}), do: true
  def is_elem_ref?(%Attribute{}), do: false

  def is_string?(%Attribute{type: :string}), do: true
  def is_string?(%Attribute{}), do: false

  def is_number?(%Attribute{type: :number}), do: true
  def is_number?(%Attribute{}), do: false

  def is_boolean?(%Attribute{type: :boolean}), do: true
  def is_boolean?(%Attribute{}), do: false

  def is_function?(%Attribute{type: :function}), do: true
  def is_function?(%Attribute{}), do: false

  def is_list?(%Attribute{type: :list}), do: true
  def is_list?(%Attribute{}), do: false
end
