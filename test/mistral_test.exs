defmodule MistralTest do
  use ExUnit.Case, async: true
  alias Mistral.Mock

  describe "init without api_key" do
    test "raises if no api_key in config" do
      Application.delete_env(:mistral, :api_key)
      assert_raise ArgumentError, fn -> Mistral.init() end
    end

    test "creates client using api_key from config" do
      Application.put_env(:mistral, :api_key, "test_key")
      client = Mistral.init()
      assert ["Bearer test_key"] = client.req.headers["authorization"]
      Application.delete_env(:mistral, :api_key)
    end
  end

  describe "init with api_key" do
    test "default client" do
      client = Mistral.init("test_key")
      assert "https://api.mistral.ai/v1" = client.req.options.base_url
      assert %{"user-agent" => _val} = client.req.headers
      assert %{"authorization" => ["Bearer test_key"]} = client.req.headers
    end

    test "client with custom req options" do
      client = Mistral.init("test_key", receive_timeout: :infinity)
      assert "https://api.mistral.ai/v1" = client.req.options.base_url
      assert :infinity = client.req.options.receive_timeout
    end

    test "client with merged headers" do
      client =
        Mistral.init("test_key",
          headers: [
            {"User-Agent", "testing"},
            {"X-Test", "testing"}
          ]
        )

      assert %{"user-agent" => ["testing"], "x-test" => ["testing"]} = client.req.headers
      assert %{"authorization" => ["Bearer test_key"]} = client.req.headers
    end
  end

  describe "chat/2" do
    setup do
      client = Mock.client(&Mock.respond(&1, :chat_completion))
      {:ok, client: client}
    end

    test "validates parameters", %{client: client} do
      assert {:error, %NimbleOptions.ValidationError{}} = Mistral.chat(client, [])

      assert {:error, %NimbleOptions.ValidationError{}} =
               Mistral.chat(client, model: "mistral-small-latest")

      assert {:error, %NimbleOptions.ValidationError{}} =
               Mistral.chat(client,
                 model: "mistral-small-latest",
                 messages: [%{role: "invalid", content: "test"}]
               )

      assert {:error, %NimbleOptions.ValidationError{}} =
               Mistral.chat(client,
                 model: "mistral-small-latest",
                 messages: [%{role: "user", content: "test"}],
                 temperature: 1
               )
    end

    test "generates a response for a given prompt", %{client: client} do
      assert {:ok, res} =
               Mistral.chat(client,
                 model: "mistral-small-latest",
                 messages: [
                   %{
                     role: "user",
                     content: "Write a haiku that starts with 'Waves crash against stone…'"
                   }
                 ]
               )

      assert res["model"] == "mistral-small-latest"
      assert res["object"] == "chat.completion"
      assert is_list(res["choices"])
      choice = Enum.at(res["choices"], 0)
      assert choice["finish_reason"] == "stop"
      assert choice["message"]["role"] == "assistant"
      assert is_binary(choice["message"]["content"])
    end

    test "handles tools parameter correctly", %{client: client} do
      tools = [
        %{
          type: "function",
          function: %{
            name: "get_weather",
            description: "Get the weather",
            parameters: %{
              type: "object",
              properties: %{
                location: %{
                  type: "string",
                  description: "The location to get weather for"
                }
              },
              required: ["location"]
            }
          }
        }
      ]

      assert {:ok, _} =
               Mistral.chat(client,
                 model: "mistral-small-latest",
                 messages: [%{role: "user", content: "What's the weather?"}],
                 tools: tools
               )
    end

    test "streams a response for a given prompt" do
      client = Mock.client(&Mock.stream(&1, :chat_completion))

      assert {:ok, stream} =
               Mistral.chat(client,
                 model: "mistral-small-latest",
                 messages: [
                   %{
                     role: "user",
                     content: "Write a haiku that starts with 'Waves crash against stone…'"
                   }
                 ],
                 stream: true
               )

      res =
        try do
          Enum.to_list(stream)
        rescue
          e ->
            flunk("Failed to collect stream: #{inspect(e)}")
        end

      assert is_list(res)
      assert length(res) > 0

      model_chunk =
        Enum.find(res, fn chunk ->
          Map.get(chunk, "model") == "mistral-small-latest"
        end)

      assert model_chunk != nil

      content_chunk =
        Enum.find(res, fn chunk ->
          choices = Map.get(chunk, "choices", [])

          Enum.any?(choices, fn choice ->
            choice = Map.get(choice, "delta", %{})
            Map.has_key?(choice, "content")
          end)
        end)

      assert content_chunk != nil
    end

    test "streams to a process" do
      {:ok, pid} = Mistral.StreamCatcher.start_link()
      client = Mock.client(&Mock.stream(&1, :chat_completion))

      assert {:ok, task} =
               Mistral.chat(client,
                 model: "mistral-small-latest",
                 messages: [
                   %{
                     role: "user",
                     content: "Write a haiku that starts with 'Waves crash against stone…'"
                   }
                 ],
                 stream: pid
               )

      assert match?(%Task{}, task)

      try do
        Task.await(task, 5000)
      rescue
        e ->
          flunk("Task failed: #{inspect(e)}")
      end

      chunks = Mistral.StreamCatcher.get_state(pid)
      assert is_list(chunks)
      assert length(chunks) > 0

      model_chunk =
        Enum.find(chunks, fn chunk ->
          Map.get(chunk, "model") == "mistral-small-latest"
        end)

      assert model_chunk != nil

      GenServer.stop(pid)
    end

    test "generates a response with tool use" do
      client = Mock.client(&Mock.respond(&1, :tool_use))

      assert {:ok, res} =
               Mistral.chat(client,
                 model: "mistral-large-latest",
                 messages: [
                   %{role: "user", content: "Why is *Donuts* considered a masterpiece?"}
                 ],
                 tools: [
                   %{
                     type: "function",
                     function: %{
                       name: "jay_dilla_facts",
                       description: "Drops knowledge bombs about Jay Dilla.",
                       parameters: %{
                         type: "object",
                         properties: %{
                           question: %{
                             type: "string",
                             description: "A question about Jay Dilla."
                           }
                         },
                         required: ["question"]
                       }
                     }
                   }
                 ],
                 tool_choice: "auto"
               )

      tool_calls =
        res["choices"]
        |> Enum.at(0)
        |> get_in(["message", "tool_calls"])

      assert is_list(tool_calls)
      tool_call = Enum.at(tool_calls, 0)

      assert get_in(tool_call, ["function", "name"]) == "jay_dilla_facts"

      assert get_in(tool_call, ["function", "arguments", "question"]) ==
               "Why is *Donuts* considered a masterpiece?"
    end

    test "streams a response with tool use" do
      client = Mock.client(&Mock.stream(&1, :tool_use))

      assert {:ok, stream} =
               Mistral.chat(client,
                 model: "mistral-large-latest",
                 messages: [
                   %{role: "user", content: "Why is *Donuts* considered a masterpiece?"}
                 ],
                 tools: [
                   %{
                     type: "function",
                     function: %{
                       name: "jay_dilla_facts",
                       description: "Drops knowledge bombs about Jay Dilla.",
                       parameters: %{
                         type: "object",
                         properties: %{
                           question: %{
                             type: "string",
                             description: "A question about Jay Dilla."
                           }
                         },
                         required: ["question"]
                       }
                     }
                   }
                 ],
                 tool_choice: "auto",
                 stream: true
               )

      res = Enum.to_list(stream)

      tool_use_chunks =
        Enum.filter(res, fn chunk ->
          choices = chunk["choices"] || []

          Enum.any?(choices, fn choice ->
            choice["message"]["tool_calls"] != nil
          end)
        end)

      assert length(tool_use_chunks) > 0

      tool_calls =
        res
        |> Enum.filter(fn chunk ->
          choices = chunk["choices"] || []

          Enum.any?(choices, fn choice ->
            choice["message"]["tool_calls"] != nil
          end)
        end)
        |> Enum.at(0)
        |> get_in(["choices", Access.at(0), "message", "tool_calls"])

      assert is_list(tool_calls)
      tool_call = Enum.at(tool_calls, 0)

      assert get_in(tool_call, ["function", "name"]) == "jay_dilla_facts"

      assert get_in(tool_call, ["function", "arguments", "question"]) ==
               "Why is *Donuts* considered a masterpiece?"
    end
  end

  describe "embed/2" do
    test "generates an embedding for a single input" do
      client = Mock.client(&Mock.respond(&1, :embedding))

      assert {:ok, res} = Mistral.embed(client, input: "Why is the sky blue?")

      assert res["model"] == "mistral-embed"
      assert is_list(res["data"])
      assert length(res["data"]) == 1

      first_embedding = List.first(res["data"])
      assert is_list(first_embedding["embedding"])
      assert length(first_embedding["embedding"]) > 0
    end

    test "generates embeddings for multiple inputs" do
      client = Mock.client(&Mock.respond(&1, :embeddings))

      assert {:ok, res} =
               Mistral.embed(client, input: ["Why is the sky blue?", "Why is the grass green?"])

      assert res["model"] == "mistral-embed"
      assert is_list(res["data"])
      assert length(res["data"]) == 2

      Enum.each(res["data"], fn embedding ->
        assert is_list(embedding["embedding"])
        assert length(embedding["embedding"]) > 0
      end)
    end
  end

  describe "upload_file/3" do
    test "uploads a file successfully" do
      client = Mock.client(&Mock.respond(&1, :file_upload))
      file_path = "test/fixtures/dummy.pdf"

      assert {:ok, response} = Mistral.upload_file(client, file_path, purpose: "ocr")
      assert response["id"] != nil
      assert response["object"] == "file"
      assert response["purpose"] == "ocr"
      assert response["filename"] != nil
    end

    test "returns error when file doesn't exist" do
      client = Mock.client(&Mock.respond(&1, :file_upload))
      file_path = "non_existent_file.pdf"

      assert {:error, %File.Error{}} = Mistral.upload_file(client, file_path, purpose: "ocr")
    end

    test "returns error with invalid purpose" do
      client = Mock.client(&Mock.respond(&1, :file_upload))
      file_path = "test/fixtures/dummy.pdf"

      assert {:error, %NimbleOptions.ValidationError{}} =
               Mistral.upload_file(client, file_path, purpose: "invalid")
    end

    test "handles API errors" do
      client = Mock.client(&Mock.respond(&1, 400))
      file_path = "test/fixtures/dummy.pdf"

      assert {:error, %Mistral.APIError{}} =
               Mistral.upload_file(client, file_path, purpose: "ocr")
    end
  end

  describe "get_file/2" do
    setup do
      file = %{
        "id" => "00edaf84-95b0-45db-8f83-f71138491f23",
        "object" => "file",
        "bytes" => 3_749_788,
        "created_at" => 1_741_023_462,
        "filename" => "test_document.pdf",
        "purpose" => "ocr",
        "sample_type" => "ocr_input",
        "source" => "upload",
        "deleted" => false,
        "num_lines" => nil
      }

      Mock.add_mock(:get_file, file)
      :ok
    end

    test "retrieves a file by ID" do
      client = Mock.client(&Mock.respond(&1, :get_file))
      assert {:ok, file} = Mistral.get_file(client, "00edaf84-95b0-45db-8f83-f71138491f23")

      assert file["id"] == "00edaf84-95b0-45db-8f83-f71138491f23"
      assert file["object"] == "file"
      assert file["purpose"] == "ocr"
      assert file["filename"] == "test_document.pdf"
    end

    test "handles file not found" do
      client = Mock.client(&Mock.respond(&1, 404))
      assert {:error, error} = Mistral.get_file(client, "nonexistent-file-id")
      assert error.status == 404
      assert error.type == "not_found"
    end
  end

  describe "get_file_url/2" do
    setup do
      signed_url = %{
        "url" => "https://storage.googleapis.com/mistral-file-uploads/signed-url-example"
      }

      Mock.add_mock(:get_file_url, signed_url)
      :ok
    end

    test "retrieves a signed URL for a file" do
      client = Mock.client(&Mock.respond(&1, :get_file_url))

      assert {:ok, response} =
               Mistral.get_file_url(client, "00edaf84-95b0-45db-8f83-f71138491f23")

      assert response["url"] ==
               "https://storage.googleapis.com/mistral-file-uploads/signed-url-example"
    end

    test "retrieves a signed URL with expiry parameter" do
      client = Mock.client(&Mock.respond(&1, :get_file_url))

      assert {:ok, response} =
               Mistral.get_file_url(client, "00edaf84-95b0-45db-8f83-f71138491f23", expiry: 48)

      assert response["url"] ==
               "https://storage.googleapis.com/mistral-file-uploads/signed-url-example"
    end

    test "handles file not found for signed URL" do
      client = Mock.client(&Mock.respond(&1, 404))
      assert {:error, error} = Mistral.get_file_url(client, "nonexistent-file-id")
      assert error.status == 404
      assert error.type == "not_found"
    end
  end

  describe "list_files/2" do
    test "lists files with no options" do
      client = Mock.client(&Mock.respond(&1, :file_list))
      assert {:ok, response} = Mistral.list_files(client)

      assert response["object"] == "list"
      assert is_list(response["data"])
      assert length(response["data"]) == 2

      file = Enum.at(response["data"], 0)
      assert is_binary(file["id"])
      assert file["object"] == "file"
    end

    test "lists files with filtering options" do
      client = Mock.client(&Mock.respond(&1, :file_list))
      assert {:ok, response} = Mistral.list_files(client, purpose: "ocr", page_size: 10)

      assert response["object"] == "list"
      assert is_list(response["data"])
    end

    test "lists files with pagination" do
      client = Mock.client(&Mock.respond(&1, :file_list))
      assert {:ok, response} = Mistral.list_files(client, page: 1, page_size: 5)

      assert response["object"] == "list"
      assert is_list(response["data"])
    end

    test "validates options" do
      client = Mock.client(&Mock.respond(&1, :file_list))

      assert {:error, %NimbleOptions.ValidationError{}} =
               Mistral.list_files(client, purpose: "invalid")

      assert {:error, %NimbleOptions.ValidationError{}} =
               Mistral.list_files(client, page: "not_a_number")
    end

    test "handles API errors" do
      client = Mock.client(&Mock.respond(&1, 401))
      assert {:error, error} = Mistral.list_files(client)
      assert error.status == 401
      assert error.type == "unauthorized"
    end
  end

  describe "delete_file/2" do
    test "deletes a file by ID" do
      client = Mock.client(&Mock.respond(&1, :file_delete))
      assert {:ok, response} = Mistral.delete_file(client, "file-abc123")

      assert response["id"] == "file-abc123"
      assert response["deleted"] == true
    end

    test "handles file not found" do
      client = Mock.client(&Mock.respond(&1, 404))
      assert {:error, error} = Mistral.delete_file(client, "nonexistent-file-id")
      assert error.status == 404
      assert error.type == "not_found"
    end
  end

  describe "download_file/2" do
    test "downloads file content as binary" do
      file_content = File.read!("test/fixtures/dummy.pdf")
      client = Mock.client(&Mock.respond_raw(&1, file_content))

      assert {:ok, body} = Mistral.download_file(client, "file-abc123")
      assert is_binary(body)
      assert body == file_content
    end

    test "handles file not found" do
      client = Mock.client(&Mock.respond(&1, 404))
      assert {:error, error} = Mistral.download_file(client, "nonexistent-file-id")
      assert error.status == 404
      assert error.type == "not_found"
    end
  end

  describe "ocr/2" do
    setup do
      client = Mock.client(&Mock.respond(&1, :ocr))
      {:ok, client: client}
    end

    test "validates parameters", %{client: client} do
      assert {:error, %NimbleOptions.ValidationError{}} = Mistral.ocr(client, [])

      assert {:error, %NimbleOptions.ValidationError{}} =
               Mistral.ocr(client, model: "mistral-ocr-latest")

      assert {:error, %NimbleOptions.ValidationError{}} =
               Mistral.ocr(client,
                 model: "mistral-ocr-latest",
                 document: %{type: "invalid_type", document_url: "https://example.com/file.pdf"}
               )
    end

    test "performs OCR on a document URL", %{client: client} do
      assert {:ok, res} =
               Mistral.ocr(client,
                 id: "ocr-123456789",
                 model: "mistral-ocr-latest",
                 document: %{type: "document_url", document_url: "https://example.com/file.pdf"}
               )

      assert res["model"] == "mistral-ocr-latest"
      assert is_list(res["pages"])

      assert Enum.all?(res["pages"], fn page ->
               is_map(page) and Map.has_key?(page, "markdown")
             end)
    end

    test "performs OCR on an image URL", %{client: client} do
      assert {:ok, res} =
               Mistral.ocr(client,
                 id: "ocr-123456789",
                 model: "mistral-ocr-latest",
                 document: %{type: "image_url", image_url: "https://example.com/image.png"}
               )

      assert res["model"] == "mistral-ocr-latest"
      assert is_list(res["pages"])

      assert Enum.all?(res["pages"], fn page ->
               is_map(page) and Map.has_key?(page, "markdown")
             end)
    end

    test "handles API validation error" do
      client = Mock.client(&Mock.respond(&1, 422))

      assert {:error, error} =
               Mistral.ocr(client,
                 id: "ocr-123456789",
                 model: "mistral-ocr-latest",
                 document: %{type: "document_url", document_url: "https://example.com/file.pdf"}
               )

      assert error.status == 422
      assert error.type == "unprocessable_entity"
    end
  end

  describe "list_models/1" do
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

      Mock.add_mock(:list_models, model_list)

      :ok
    end

    test "lists all available models" do
      client = Mock.client(&Mock.respond(&1, :list_models))
      assert {:ok, response} = Mistral.list_models(client)

      assert response["object"] == "list"
      assert is_list(response["data"])

      model = Enum.at(response["data"], 0)
      assert is_map(model)
      assert is_binary(model["id"])
      assert is_map(model["capabilities"])
    end

    test "handles errors" do
      client = Mock.client(&Mock.respond(&1, 401))
      assert {:error, error} = Mistral.list_models(client)
      assert error.status == 401
      assert error.type == "unauthorized"
    end
  end

  describe "get_model/2" do
    setup do
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

      Mock.add_mock(:get_model, model)

      :ok
    end

    test "retrieves a specific model by ID" do
      client = Mock.client(&Mock.respond(&1, :get_model))
      assert {:ok, model} = Mistral.get_model(client, "mistral-small-latest")

      assert model["id"] == "mistral-small-latest"
      assert model["object"] == "model"
      assert is_map(model["capabilities"])
    end

    test "handles model not found" do
      client = Mock.client(&Mock.respond(&1, 404))
      assert {:error, error} = Mistral.get_model(client, "nonexistent-model")
      assert error.status == 404
      assert error.type == "not_found"
    end
  end

  describe "response format control" do
    setup do
      client = Mock.client(&Mock.respond(&1, :chat_completion))
      {:ok, client: client}
    end

    test "supports JSON object mode", %{client: client} do
      assert {:ok, res} =
               Mistral.chat(client,
                 model: "mistral-small-latest",
                 messages: [%{role: "user", content: "Generate a JSON"}],
                 response_format: %{type: "json_object"}
               )

      assert res["choices"]
    end

    test "supports JSON schema mode", %{client: client} do
      schema = %{
        type: "object",
        title: "UserInfo",
        properties: %{
          name: %{type: "string", title: "Name"},
          age: %{type: "integer", title: "Age"}
        },
        required: ["name", "age"],
        additionalProperties: false
      }

      assert {:ok, res} =
               Mistral.chat(client,
                 model: "mistral-small-latest",
                 messages: [%{role: "user", content: "Generate user info"}],
                 response_format: %{
                   type: "json_schema",
                   json_schema: %{
                     name: "user_info",
                     schema: schema,
                     strict: true
                   }
                 }
               )

      assert res["choices"]
    end

    test "validates response format type", %{client: client} do
      assert {:error, %NimbleOptions.ValidationError{}} =
               Mistral.chat(client,
                 model: "mistral-small-latest",
                 messages: [%{role: "user", content: "Test"}],
                 response_format: %{type: "invalid_type"}
               )
    end

    test "requires json_schema when type is json_schema", %{client: client} do
      assert {:error, %NimbleOptions.ValidationError{}} =
               Mistral.chat(client,
                 model: "mistral-small-latest",
                 messages: [%{role: "user", content: "Test"}],
                 response_format: %{type: "json_schema"}
               )
    end

    test "rejects nil json_schema when type is json_schema", %{client: client} do
      assert {:error, %NimbleOptions.ValidationError{}} =
               Mistral.chat(client,
                 model: "mistral-small-latest",
                 messages: [%{role: "user", content: "Test"}],
                 response_format: %{type: "json_schema", json_schema: nil}
               )
    end

    test "defaults to text format when not specified", %{client: client} do
      assert {:ok, res} =
               Mistral.chat(client,
                 model: "mistral-small-latest",
                 messages: [%{role: "user", content: "Test"}]
               )

      assert res["choices"]
    end
  end

  describe "OCR with response format" do
    setup do
      client = Mock.client(&Mock.respond(&1, :ocr))
      {:ok, client: client}
    end

    test "supports bbox annotation format", %{client: client} do
      schema = %{
        type: "object",
        title: "BboxAnnotation",
        properties: %{
          text: %{type: "string", title: "Text"},
          confidence: %{type: "number", title: "Confidence"}
        },
        additionalProperties: false
      }

      assert {:ok, res} =
               Mistral.ocr(client,
                 model: "mistral-ocr-latest",
                 document: %{
                   type: "document_url",
                   document_url: "https://example.com/doc.pdf"
                 },
                 bbox_annotation_format: %{
                   type: "json_schema",
                   json_schema: %{
                     name: "bbox_annotation",
                     schema: schema
                   }
                 }
               )

      assert res["pages"]
    end

    test "supports document annotation format", %{client: client} do
      schema = %{
        type: "object",
        title: "DocumentAnnotation",
        properties: %{
          title: %{type: "string", title: "Title"},
          summary: %{type: "string", title: "Summary"}
        },
        additionalProperties: false
      }

      assert {:ok, res} =
               Mistral.ocr(client,
                 model: "mistral-ocr-latest",
                 document: %{
                   type: "document_url",
                   document_url: "https://example.com/doc.pdf"
                 },
                 document_annotation_format: %{
                   type: "json_schema",
                   json_schema: %{
                     name: "document_annotation",
                     schema: schema
                   }
                 }
               )

      assert res["pages"]
    end
  end
end
