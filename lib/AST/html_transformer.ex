defmodule Rez.AST.HtmlTransformer do
  @moduledoc """
  Implements an HTML transformation pipeline.

  Presently only used for transforming links.
  """
  alias Rez.AST.LinkTransformer

  def transform(html) do
    html
    |> LinkTransformer.transform()
  end
end
