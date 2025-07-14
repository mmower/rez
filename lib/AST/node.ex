defprotocol Rez.AST.Node do
  @moduledoc """
  `Rez.AST.Node` defines a protocol that AST nodes are meant to implement.
  """

  @doc """
  `node_type/1` should return a String containing the type of the node, e.g.
  `"card"`.
  """
  def node_type(node)

  @doc """
  `process/1` should handle any post-processing of the given node.
  """
  def process(node, resources)

  @doc """
  `js_ctor/1` should return the Javascript constructor function for this node
  type.
  """
  def js_ctor(node)

  @doc """
  `js_initializer/1` should return the Javascript code to initialize a node
  of this type.
  """
  def js_initializer(node)

  @doc """
  `html_processor/2` returns a function that processes & wraps HTML content generated
  from an attribute (assumed to be a template)
  """
  def html_processor(node, attr_name)
end
