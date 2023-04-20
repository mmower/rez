defprotocol Rez.AST.Node do
  @moduledoc """
  `Rez.AST.Node` defines a protocol that AST nodes are meant to implement.
  """

  @doc """
  `node_type/1` should return a String containing the type of the node, e.g.
  `"item"`.
  """
  def node_type(node)

  @doc """
  `default_attribues/1` returns a `Map` of default attributes based on the
  Node type.
  """
  def default_attributes(node)

  @doc """
  The `pre_process/1` function is intended to be called after a Node structure
  has been created. It gives the node a chance to response to its own creation.
  """
  def pre_process(node)

  @doc """
  `process/1` should handle any post-processing of the given node.
  """
  def process(node)

  @doc """
  `children/1` should return a list of the children of the given node
  """
  def children(node)

  @doc """
  `validators/1` should return a list of validation functions that determine
  whether the node has been correctly specified.
  """
  def validators(node)

  @doc """
  `js_ctor/1` should return the Javascript constructor function for this node
  type.
  """
  def js_ctor(node)
end
