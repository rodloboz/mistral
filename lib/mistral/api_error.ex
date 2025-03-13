defmodule Mistral.APIError do
  @moduledoc """
  Exception raised when the Mistral API returns an error.
  """
  defexception [:status, :type, :message]

  @impl true
  def exception(%{status: status, body: %{"error" => %{"type" => type, "message" => message}}}) do
    struct(__MODULE__,
      status: status,
      type: type,
      message: message
    )
  end

  def exception(%{status: status, body: %{"error" => error}}) when is_map(error) do
    message = Map.get(error, "message", "Unknown error message")
    type = Map.get(error, "type", "unknown_error")

    struct(__MODULE__,
      status: status,
      type: type,
      message: message
    )
  end

  def exception(%{status: status, body: ""}) do
    struct(__MODULE__,
      status: status,
      type: "empty_response",
      message: "Empty response received"
    )
  end

  def exception(%{status: status}) do
    struct(__MODULE__,
      status: status,
      type: "http_error",
      message: "HTTP status #{status}"
    )
  end

  @impl true
  def message(%__MODULE__{type: type, message: message, status: status}) do
    "Mistral API Error (#{status}): [#{type}] #{message}"
  end
end
