defmodule Mistral.Schemas do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      Module.register_attribute(__MODULE__, :schemas, accumulate: true)
      import Mistral.Schemas
    end
  end

  @doc """
  Returns documentation for the given schema.
  """
  @spec doc(atom()) :: Macro.t()
  defmacro doc(key) do
    quote do
      @schemas
      |> Keyword.get(unquote(key))
      |> NimbleOptions.docs()
      |> String.replace("\n\n", "\n")
    end
  end

  @doc """
  Registers a schema using the specified key and options.
  """
  @spec schema(atom(), NimbleOptions.schema()) :: Macro.t()
  defmacro schema(key, opts) do
    quote do
      @schemas {unquote(key), NimbleOptions.new!(unquote(opts))}
    end
  end

  @doc """
  Fetches a schema by the given key.
  """
  @spec schema(atom()) :: Macro.t()
  defmacro schema(key) do
    quote do
      Keyword.fetch!(@schemas, unquote(key))
    end
  end

  @doc """
  Registers a nested schema to be used within another schema.
  """
  @spec nested_schema(atom()) :: Macro.t()
  defmacro nested_schema(key) do
    quote do
      Keyword.fetch!(@schemas, unquote(key)).schema
    end
  end
end
