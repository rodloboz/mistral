defmodule Mistral.ModelsTest do
  use ExUnit.Case, async: true
  alias Mistral.Mock

  setup do
    model_list = %{
      "object" => "list",
      "data" => [
        %{
          "id" => "mistral-small-latest",
          "object" => "model",
          "created" => 1_711_430_400,
          "owned_by" => "mistralai",
          "capabilities" => %{
            "completion_chat" => true,
            "completion_fim" => false,
            "function_calling" => true,
            "fine_tuning" => false,
            "vision" => false
          },
          "name" => "Mistral Small",
          "description" => "Mistral AI's flagship small model",
          "max_context_length" => 32_768,
          "aliases" => ["mistral-small"],
          "type" => "base"
        },
        %{
          "id" => "mistral-large-latest",
          "object" => "model",
          "created" => 1_711_430_400,
          "owned_by" => "mistralai",
          "capabilities" => %{
            "completion_chat" => true,
            "completion_fim" => false,
            "function_calling" => true,
            "fine_tuning" => false,
            "vision" => true
          },
          "name" => "Mistral Large",
          "description" => "Mistral AI's flagship large model",
          "max_context_length" => 32_768,
          "aliases" => ["mistral-large"],
          "type" => "base"
        }
      ]
    }

    model = %{
      "id" => "mistral-small-latest",
      "object" => "model",
      "created" => 1_711_430_400,
      "owned_by" => "mistralai",
      "capabilities" => %{
        "completion_chat" => true,
        "completion_fim" => false,
        "function_calling" => true,
        "fine_tuning" => false,
        "vision" => false
      },
      "name" => "Mistral Small",
      "description" => "Mistral AI's flagship small model",
      "max_context_length" => 32_768,
      "aliases" => ["mistral-small"],
      "type" => "base"
    }

    Mock.add_mock(:list_models, model_list)
    Mock.add_mock(:get_model, model)

    :ok
  end

  describe "list/1" do
    test "lists all available models" do
      client = Mock.client(&Mock.respond(&1, :list_models))
      assert {:ok, response} = Mistral.Models.list(client)

      assert response["object"] == "list"
      assert is_list(response["data"])

      model = Enum.at(response["data"], 0)
      assert is_map(model)
      assert is_binary(model["id"])
      assert is_map(model["capabilities"])
    end

    test "handles errors" do
      client = Mock.client(&Mock.respond(&1, 401))
      assert {:error, error} = Mistral.Models.list(client)
      assert error.status == 401
      assert error.type == "unauthorized"
    end
  end

  describe "get/2" do
    test "retrieves a specific model by ID" do
      client = Mock.client(&Mock.respond(&1, :get_model))
      assert {:ok, model} = Mistral.Models.get(client, "mistral-small-latest")

      assert model["id"] == "mistral-small-latest"
      assert model["object"] == "model"
      assert is_map(model["capabilities"])
    end

    test "handles model not found" do
      client = Mock.client(&Mock.respond(&1, 404))
      assert {:error, error} = Mistral.Models.get(client, "nonexistent-model")
      assert error.status == 404
      assert error.type == "not_found"
    end
  end
end
