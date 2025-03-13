defmodule Mistral.Models do
  @moduledoc """
  Functions for interacting with the Mistral Models API.

  This module provides functionality to retrieve information about
  the available models and their capabilities.
  """
  use Mistral.Schemas

  defstruct [:client]

  schema(:list_params, [
    # Currently no parameters are used, but this structure allows for future
    # expansion if the API adds pagination or filtering
  ])

  @doc """
  Lists all available models.

  ## Examples

      iex> Mistral.Models.list(client)
      {:ok, %{
        "object" => "list",
        "data" => [
          %{
            "id" => "mistral-small-latest",
            "object" => "model",
            "created" => 1711430400,
            "owned_by" => "mistralai",
            "capabilities" => %{
              "completion_chat" => true,
              "function_calling" => true
            }
          }
        ]
      }}
  """
  @spec list(Mistral.client(), keyword()) :: Mistral.response()
  def list(%Mistral{} = client, params \\ []) do
    with {:ok, params} <- NimbleOptions.validate(params, schema(:list_params)) do
      req(client, :get, "/models", params: params)
    end
  end

  @doc """
  Retrieves information about a specific model by its ID.

  ## Parameters

    - `client`: A `Mistral.client()` struct.
    - `model_id`: The ID of the model to retrieve (e.g. "mistral-small-latest").

  ## Examples

      iex> Mistral.Models.get(client, "mistral-small-latest")
      {:ok, %{
        "id" => "mistral-small-latest",
        "object" => "model",
        "created" => 1711430400,
        "owned_by" => "mistralai",
        "capabilities" => %{
          "completion_chat" => true,
          "function_calling" => true,
          "vision" => false
        },
        "name" => "Mistral Small"
      }}
  """
  @spec get(Mistral.client(), String.t()) :: Mistral.response()
  def get(%Mistral{} = client, model_id) when is_binary(model_id) do
    req(client, :get, "/models/#{model_id}")
  end

  # Helper function to make requests and process responses.
  @spec req(Mistral.client(), atom(), String.t(), keyword()) :: Mistral.response()
  defp req(%Mistral{} = client, method, path, opts \\ []) do
    client
    |> Mistral.req(method, path, opts)
    |> Mistral.res()
  end
end
