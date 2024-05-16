defmodule Hexdump do
  @moduledoc """
  Hexdump

  https://github.com/pcorey/bitcoin_network/blob/master/lib/hexdump.ex
  """

  def to_string(data) when is_binary(data),
    do:
      data
      |> :binary.bin_to_list()
      |> Enum.chunk_every(16)
      |> Enum.map(&Enum.chunk_every(&1, 8))
      |> Enum.map(fn
        [a] -> [a, []]
        [a, b] -> [a, b]
      end)
      |> Enum.with_index()
      |> Enum.map(&line_to_string/1)
      |> Enum.join("\n")

  def to_string(data),
    do: Kernel.inspect(data)

  def line_to_string({parts, index}) do
    count =
      index
      |> Kernel.*(16)
      |> :binary.encode_unsigned()
      |> Base.encode16(case: :lower)
      |> String.pad_leading(8, "0")

    bytes =
      parts
      |> Enum.map(fn bytes ->
        bytes
        |> Enum.map(fn byte ->
          byte
          |> :binary.encode_unsigned()
          |> Base.encode16(case: :lower)
        end)
        |> Enum.join(" ")
        |> String.pad_trailing(23, " ")
      end)

    ascii =
      parts
      |> List.flatten()
      |> Enum.map(fn byte ->
        case byte <= 0x7E && byte >= 0x20 do
          true -> <<byte>>
          false -> "."
        end
      end)
      |> Enum.join("")

    [count, bytes, ascii]
    |> List.flatten()
    |> Enum.join("  ")
  end
end
