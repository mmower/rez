defmodule Rez.AST.HtmlTransformer do
  alias Rez.AST.LinkTransformer

  def transform(html) do
    html
    |> LinkTransformer.transform()
  end
end
