defmodule Rez.Compiler.IOError do
  @moduledoc """
  `Rez.Compiler.IOError` provides functions for handling file read/write
  errors and amending the current `Compilation` accordingly.
  """

  alias Rez.Compiler.Compilation

  def file_read_error(
        %Compilation{errors: errors} = compilation,
        code,
        file_description,
        file_path
      ) do
    # Given a file read error, update the compilation error status & add a customised message
    case code do
      :enoent ->
        %{
          compilation
          | status: :error,
            errors: ["#{file_description} #{file_path} does not exist" | errors]
        }

      :eacces ->
        %{
          compilation
          | status: :error,
            errors: ["Invalid permissions to read #{file_path}" | errors]
        }

      :eisdir ->
        %{
          compilation
          | status: :error,
            errors: ["#{file_description} #{file_path} is a directory" | errors]
        }

      :enotdir ->
        %{compilation | status: :error, errors: ["Invalid path #{file_path}" | errors]}

      :enomem ->
        %{
          compilation
          | status: :error,
            errors: ["#{file_description} #{file_path} is too big to fit in memory" | errors]
        }

      unknown ->
        %{
          compilation
          | status: :error,
            errors: ["Unknown error #{unknown} reading #{file_path}" | errors]
        }
    end
  end

  def file_write_error(
        %Compilation{errors: errors} = compilation,
        code,
        file_description,
        file_path
      ) do
    # Given a file write error, update the compilation error status & add a customised message
    case code do
      :enoent ->
        %{
          compilation
          | status: :error,
            errors: ["#{file_description} #{file_path} is not a valid path" | errors]
        }

      :enotdir ->
        %{
          compilation
          | status: :error,
            errors: ["#{file_description} #{file_path} is not a valid path" | errors]
        }

      :enospc ->
        %{compilation | status: :error, errors: ["No space left to write #{file_path}" | errors]}

      :eacces ->
        %{
          compilation
          | status: :error,
            errors: ["Invalid permissions to write #{file_path}" | errors]
        }

      :eisdir ->
        %{
          compilation
          | status: :error,
            errors: ["#{file_description} #{file_path} is a directory" | errors]
        }

      unknown ->
        %{
          compilation
          | status: :error,
            errors: ["Unknown error #{unknown} writing #{file_path}" | errors]
        }
    end
  end
end
