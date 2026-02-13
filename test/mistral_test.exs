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
      assert res != []

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
      assert chunks != []

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

      assert tool_use_chunks != []

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
      assert [first_embedding] = res["data"]
      assert is_list(first_embedding["embedding"])
      assert first_embedding["embedding"] != []
    end

    test "generates embeddings for multiple inputs" do
      client = Mock.client(&Mock.respond(&1, :embeddings))

      assert {:ok, res} =
               Mistral.embed(client, input: ["Why is the sky blue?", "Why is the grass green?"])

      assert res["model"] == "mistral-embed"
      assert is_list(res["data"])
      assert [_, _] = res["data"]

      Enum.each(res["data"], fn embedding ->
        assert is_list(embedding["embedding"])
        assert embedding["embedding"] != []
      end)
    end
  end

  describe "fim/2" do
    setup do
      client = Mock.client(&Mock.respond(&1, :fim_completion))
      {:ok, client: client}
    end

    test "validates parameters", %{client: client} do
      assert {:error, %NimbleOptions.ValidationError{}} = Mistral.fim(client, [])

      assert {:error, %NimbleOptions.ValidationError{}} =
               Mistral.fim(client, model: "codestral-latest")

      assert {:error, %NimbleOptions.ValidationError{}} =
               Mistral.fim(client, prompt: "def add(a, b):\n    ")
    end

    test "completes code with prompt only", %{client: client} do
      assert {:ok, res} =
               Mistral.fim(client,
                 model: "codestral-latest",
                 prompt: "def add(a, b):\n    "
               )

      assert res["model"] == "codestral-latest"
      assert res["object"] == "chat.completion"
      assert is_list(res["choices"])
      choice = Enum.at(res["choices"], 0)
      assert choice["finish_reason"] == "stop"
      assert choice["message"]["role"] == "assistant"
      assert is_binary(choice["message"]["content"])
    end

    test "completes code with prompt and suffix", %{client: client} do
      assert {:ok, res} =
               Mistral.fim(client,
                 model: "codestral-latest",
                 prompt: "def ",
                 suffix: "return a + b"
               )

      assert res["model"] == "codestral-latest"
      assert is_list(res["choices"])
      choice = Enum.at(res["choices"], 0)
      assert is_binary(choice["message"]["content"])
    end

    test "streams a response" do
      client = Mock.client(&Mock.stream(&1, :fim_completion))

      assert {:ok, stream} =
               Mistral.fim(client,
                 model: "codestral-latest",
                 prompt: "def ",
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
      assert res != []

      model_chunk =
        Enum.find(res, fn chunk ->
          Map.get(chunk, "model") == "codestral-latest"
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
      client = Mock.client(&Mock.stream(&1, :fim_completion))

      assert {:ok, task} =
               Mistral.fim(client,
                 model: "codestral-latest",
                 prompt: "def ",
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
      assert chunks != []

      model_chunk =
        Enum.find(chunks, fn chunk ->
          Map.get(chunk, "model") == "codestral-latest"
        end)

      assert model_chunk != nil

      GenServer.stop(pid)
    end

    test "handles stop parameter", %{client: client} do
      assert {:ok, _res} =
               Mistral.fim(client,
                 model: "codestral-latest",
                 prompt: "def add(a, b):\n    ",
                 stop: "\n"
               )

      assert {:ok, _res} =
               Mistral.fim(client,
                 model: "codestral-latest",
                 prompt: "def add(a, b):\n    ",
                 stop: ["\n", "\n\n"]
               )
    end

    test "handles API errors" do
      client = Mock.client(&Mock.respond(&1, 422))

      assert {:error, %Mistral.APIError{} = error} =
               Mistral.fim(client,
                 model: "codestral-latest",
                 prompt: "def add(a, b):\n    "
               )

      assert error.status == 422
      assert error.type == "unprocessable_entity"
    end
  end

  describe "classify/2" do
    test "validates parameters" do
      client = Mock.client(&Mock.respond(&1, :classification))

      assert {:error, %NimbleOptions.ValidationError{}} = Mistral.classify(client, [])

      assert {:error, %NimbleOptions.ValidationError{}} =
               Mistral.classify(client, model: "mistral-moderation-latest")

      assert {:error, %NimbleOptions.ValidationError{}} =
               Mistral.classify(client, input: "Hello")
    end

    test "classifies a single text input" do
      client = Mock.client(&Mock.respond(&1, :classification))

      assert {:ok, res} =
               Mistral.classify(client,
                 model: "mistral-moderation-latest",
                 input: "Hello, world!"
               )

      assert res["model"] == "mistral-moderation-latest"
      assert is_list(res["results"])
      assert [result] = res["results"]
      assert is_map(result["category_scores"])
    end

    test "classifies multiple text inputs" do
      client = Mock.client(&Mock.respond(&1, :classifications))

      assert {:ok, res} =
               Mistral.classify(client,
                 model: "mistral-moderation-latest",
                 input: ["First text", "Second text"]
               )

      assert res["model"] == "mistral-moderation-latest"
      assert is_list(res["results"])
      assert length(res["results"]) == 2
    end

    test "handles API errors" do
      client = Mock.client(&Mock.respond(&1, 401))

      assert {:error, %Mistral.APIError{} = error} =
               Mistral.classify(client,
                 model: "mistral-moderation-latest",
                 input: "Hello"
               )

      assert error.status == 401
      assert error.type == "unauthorized"
    end
  end

  describe "classify_chat/2" do
    test "validates parameters" do
      client = Mock.client(&Mock.respond(&1, :classification))

      assert {:error, %NimbleOptions.ValidationError{}} = Mistral.classify_chat(client, [])

      assert {:error, %NimbleOptions.ValidationError{}} =
               Mistral.classify_chat(client, model: "mistral-moderation-latest")

      assert {:error, %NimbleOptions.ValidationError{}} =
               Mistral.classify_chat(client, input: %{messages: [%{role: "user", content: "Hi"}]})
    end

    test "classifies a single conversation" do
      client = Mock.client(&Mock.respond(&1, :classification))

      assert {:ok, res} =
               Mistral.classify_chat(client,
                 model: "mistral-moderation-latest",
                 input: %{messages: [%{role: "user", content: "Hello"}]}
               )

      assert res["model"] == "mistral-moderation-latest"
      assert is_list(res["results"])
      assert [result] = res["results"]
      assert is_map(result["category_scores"])
    end

    test "classifies multiple conversations" do
      client = Mock.client(&Mock.respond(&1, :classifications))

      assert {:ok, res} =
               Mistral.classify_chat(client,
                 model: "mistral-moderation-latest",
                 input: [
                   %{messages: [%{role: "user", content: "Hello"}]},
                   %{messages: [%{role: "user", content: "Goodbye"}]}
                 ]
               )

      assert res["model"] == "mistral-moderation-latest"
      assert is_list(res["results"])
      assert length(res["results"]) == 2
    end

    test "handles API errors" do
      client = Mock.client(&Mock.respond(&1, 422))

      assert {:error, %Mistral.APIError{} = error} =
               Mistral.classify_chat(client,
                 model: "mistral-moderation-latest",
                 input: %{messages: [%{role: "user", content: "Hello"}]}
               )

      assert error.status == 422
      assert error.type == "unprocessable_entity"
    end
  end

  describe "moderate/2" do
    test "validates parameters" do
      client = Mock.client(&Mock.respond(&1, :moderation))

      assert {:error, %NimbleOptions.ValidationError{}} = Mistral.moderate(client, [])

      assert {:error, %NimbleOptions.ValidationError{}} =
               Mistral.moderate(client, model: "mistral-moderation-latest")

      assert {:error, %NimbleOptions.ValidationError{}} =
               Mistral.moderate(client, input: "Hello")
    end

    test "moderates a single text input" do
      client = Mock.client(&Mock.respond(&1, :moderation))

      assert {:ok, res} =
               Mistral.moderate(client,
                 model: "mistral-moderation-latest",
                 input: "Hello, world!"
               )

      assert res["model"] == "mistral-moderation-latest"
      assert is_list(res["results"])
      assert [result] = res["results"]
      assert is_map(result["categories"])
      assert is_map(result["category_scores"])

      Enum.each(result["categories"], fn {_key, val} ->
        assert is_boolean(val)
      end)

      Enum.each(result["category_scores"], fn {_key, val} ->
        assert is_number(val)
      end)
    end

    test "moderates multiple text inputs" do
      client = Mock.client(&Mock.respond(&1, :moderations))

      assert {:ok, res} =
               Mistral.moderate(client,
                 model: "mistral-moderation-latest",
                 input: ["First text", "Second text"]
               )

      assert res["model"] == "mistral-moderation-latest"
      assert is_list(res["results"])
      assert length(res["results"]) == 2
    end

    test "handles API errors" do
      client = Mock.client(&Mock.respond(&1, 401))

      assert {:error, %Mistral.APIError{} = error} =
               Mistral.moderate(client,
                 model: "mistral-moderation-latest",
                 input: "Hello"
               )

      assert error.status == 401
      assert error.type == "unauthorized"
    end
  end

  describe "moderate_chat/2" do
    test "validates parameters" do
      client = Mock.client(&Mock.respond(&1, :moderation))

      assert {:error, %NimbleOptions.ValidationError{}} = Mistral.moderate_chat(client, [])

      assert {:error, %NimbleOptions.ValidationError{}} =
               Mistral.moderate_chat(client, model: "mistral-moderation-latest")

      assert {:error, %NimbleOptions.ValidationError{}} =
               Mistral.moderate_chat(client,
                 input: [%{role: "user", content: "Hello"}]
               )
    end

    test "moderates a single conversation" do
      client = Mock.client(&Mock.respond(&1, :moderation))

      assert {:ok, res} =
               Mistral.moderate_chat(client,
                 model: "mistral-moderation-latest",
                 input: [%{role: "user", content: "Hello"}]
               )

      assert res["model"] == "mistral-moderation-latest"
      assert is_list(res["results"])
      assert [result] = res["results"]
      assert is_map(result["categories"])
      assert is_map(result["category_scores"])
    end

    test "moderates multiple conversations" do
      client = Mock.client(&Mock.respond(&1, :moderations))

      assert {:ok, res} =
               Mistral.moderate_chat(client,
                 model: "mistral-moderation-latest",
                 input: [
                   [%{role: "user", content: "Hello"}],
                   [%{role: "user", content: "Goodbye"}]
                 ]
               )

      assert res["model"] == "mistral-moderation-latest"
      assert is_list(res["results"])
      assert length(res["results"]) == 2
    end

    test "handles API errors" do
      client = Mock.client(&Mock.respond(&1, 422))

      assert {:error, %Mistral.APIError{} = error} =
               Mistral.moderate_chat(client,
                 model: "mistral-moderation-latest",
                 input: [%{role: "user", content: "Hello"}]
               )

      assert error.status == 422
      assert error.type == "unprocessable_entity"
    end
  end

  describe "create_batch_job/2" do
    setup do
      client = Mock.client(&Mock.respond(&1, :batch_job))
      {:ok, client: client}
    end

    test "validates parameters - missing endpoint", %{client: client} do
      assert {:error, %NimbleOptions.ValidationError{}} =
               Mistral.create_batch_job(client, input_files: ["file-abc123"])
    end

    test "creates a batch job with input_files", %{client: client} do
      assert {:ok, res} =
               Mistral.create_batch_job(client,
                 endpoint: "/v1/chat/completions",
                 input_files: ["file-abc123"]
               )

      assert res["id"] == "b_abc123"
      assert res["object"] == "batch"
      assert res["status"] == "QUEUED"
      assert res["endpoint"] == "/v1/chat/completions"
      assert res["input_files"] == ["file-abc123"]
    end

    test "creates a batch job with inline requests", %{client: client} do
      assert {:ok, res} =
               Mistral.create_batch_job(client,
                 endpoint: "/v1/chat/completions",
                 model: "mistral-small-latest",
                 requests: [
                   %{
                     custom_id: "req-1",
                     body: %{
                       messages: [%{role: "user", content: "Hello"}]
                     }
                   }
                 ]
               )

      assert res["id"] == "b_abc123"
      assert res["status"] == "QUEUED"
    end

    test "accepts metadata and timeout_hours", %{client: client} do
      assert {:ok, res} =
               Mistral.create_batch_job(client,
                 endpoint: "/v1/chat/completions",
                 input_files: ["file-abc123"],
                 metadata: %{project: "test"},
                 timeout_hours: 48
               )

      assert res["id"] == "b_abc123"
    end

    test "handles API errors" do
      client = Mock.client(&Mock.respond(&1, 422))

      assert {:error, %Mistral.APIError{} = error} =
               Mistral.create_batch_job(client,
                 endpoint: "/v1/chat/completions",
                 input_files: ["file-abc123"]
               )

      assert error.status == 422
      assert error.type == "unprocessable_entity"
    end
  end

  describe "list_batch_jobs/2" do
    test "lists batch jobs with no options" do
      client = Mock.client(&Mock.respond(&1, :batch_jobs))
      assert {:ok, res} = Mistral.list_batch_jobs(client)

      assert res["object"] == "list"
      assert is_list(res["data"])
      assert length(res["data"]) == 2
      assert res["total"] == 2

      job = Enum.at(res["data"], 0)
      assert job["id"] == "b_abc123"
      assert job["object"] == "batch"
    end

    test "lists batch jobs with filtering options" do
      client = Mock.client(&Mock.respond(&1, :batch_jobs))

      assert {:ok, res} =
               Mistral.list_batch_jobs(client,
                 model: "mistral-small-latest",
                 status: ["QUEUED", "RUNNING"]
               )

      assert res["object"] == "list"
      assert is_list(res["data"])
    end

    test "lists batch jobs with pagination" do
      client = Mock.client(&Mock.respond(&1, :batch_jobs))
      assert {:ok, res} = Mistral.list_batch_jobs(client, page: 0, page_size: 10)

      assert res["object"] == "list"
      assert is_list(res["data"])
    end

    test "handles API errors" do
      client = Mock.client(&Mock.respond(&1, 401))

      assert {:error, %Mistral.APIError{} = error} = Mistral.list_batch_jobs(client)

      assert error.status == 401
      assert error.type == "unauthorized"
    end
  end

  describe "get_batch_job/3" do
    test "retrieves a batch job by ID" do
      client = Mock.client(&Mock.respond(&1, :batch_job))
      assert {:ok, res} = Mistral.get_batch_job(client, "b_abc123")

      assert res["id"] == "b_abc123"
      assert res["object"] == "batch"
      assert res["status"] == "QUEUED"
      assert res["endpoint"] == "/v1/chat/completions"
      assert res["model"] == "mistral-small-latest"
      assert res["total_requests"] == 2
    end

    test "retrieves a batch job with inline option" do
      client = Mock.client(&Mock.respond(&1, :batch_job))
      assert {:ok, res} = Mistral.get_batch_job(client, "b_abc123", inline: true)

      assert res["id"] == "b_abc123"
    end

    test "handles job not found" do
      client = Mock.client(&Mock.respond(&1, 404))

      assert {:error, %Mistral.APIError{} = error} =
               Mistral.get_batch_job(client, "nonexistent-job-id")

      assert error.status == 404
      assert error.type == "not_found"
    end
  end

  describe "cancel_batch_job/2" do
    test "cancels a batch job" do
      client = Mock.client(&Mock.respond(&1, :batch_job_cancelled))
      assert {:ok, res} = Mistral.cancel_batch_job(client, "b_abc123")

      assert res["id"] == "b_abc123"
      assert res["status"] == "CANCELLATION_REQUESTED"
    end

    test "handles job not found" do
      client = Mock.client(&Mock.respond(&1, 404))

      assert {:error, %Mistral.APIError{} = error} =
               Mistral.cancel_batch_job(client, "nonexistent-job-id")

      assert error.status == 404
      assert error.type == "not_found"
    end
  end

  describe "create_fine_tuning_job/2" do
    setup do
      client = Mock.client(&Mock.respond(&1, :fine_tuning_job))
      {:ok, client: client}
    end

    test "validates missing model", %{client: client} do
      assert {:error, %NimbleOptions.ValidationError{}} =
               Mistral.create_fine_tuning_job(client,
                 hyperparameters: %{training_steps: 10}
               )
    end

    test "validates missing hyperparameters", %{client: client} do
      assert {:error, %NimbleOptions.ValidationError{}} =
               Mistral.create_fine_tuning_job(client,
                 model: "open-mistral-7b"
               )
    end

    test "validates invalid model", %{client: client} do
      assert {:error, %NimbleOptions.ValidationError{}} =
               Mistral.create_fine_tuning_job(client,
                 model: "invalid-model",
                 hyperparameters: %{training_steps: 10}
               )
    end

    test "creates with training files", %{client: client} do
      assert {:ok, res} =
               Mistral.create_fine_tuning_job(client,
                 model: "open-mistral-7b",
                 hyperparameters: %{training_steps: 10},
                 training_files: [%{file_id: "file-abc123"}]
               )

      assert res["id"] == "ft-abc123"
      assert res["object"] == "fine_tuning.job"
      assert res["status"] == "QUEUED"
      assert res["model"] == "open-mistral-7b"
    end

    test "creates with dry_run" do
      client = Mock.client(&Mock.respond(&1, :fine_tuning_job_dry_run))

      assert {:ok, res} =
               Mistral.create_fine_tuning_job(client,
                 model: "open-mistral-7b",
                 hyperparameters: %{training_steps: 10},
                 dry_run: true
               )

      assert res["expected_duration_seconds"] == 300
      assert res["data_tokens"] == 50_000
    end

    test "creates with integrations", %{client: client} do
      assert {:ok, res} =
               Mistral.create_fine_tuning_job(client,
                 model: "open-mistral-7b",
                 hyperparameters: %{training_steps: 10},
                 integrations: [
                   %{
                     type: "wandb",
                     project: "my-project",
                     api_key: String.duplicate("a", 40)
                   }
                 ]
               )

      assert res["id"] == "ft-abc123"
    end

    test "handles API errors" do
      client = Mock.client(&Mock.respond(&1, 422))

      assert {:error, %Mistral.APIError{} = error} =
               Mistral.create_fine_tuning_job(client,
                 model: "open-mistral-7b",
                 hyperparameters: %{training_steps: 10}
               )

      assert error.status == 422
      assert error.type == "unprocessable_entity"
    end
  end

  describe "list_fine_tuning_jobs/2" do
    test "lists with no options" do
      client = Mock.client(&Mock.respond(&1, :fine_tuning_jobs))
      assert {:ok, res} = Mistral.list_fine_tuning_jobs(client)

      assert res["object"] == "list"
      assert is_list(res["data"])
      assert length(res["data"]) == 2
      assert res["total"] == 2

      job = Enum.at(res["data"], 0)
      assert job["id"] == "ft-abc123"
      assert job["object"] == "fine_tuning.job"
    end

    test "lists with filters" do
      client = Mock.client(&Mock.respond(&1, :fine_tuning_jobs))

      assert {:ok, res} =
               Mistral.list_fine_tuning_jobs(client,
                 model: "open-mistral-7b",
                 status: "RUNNING"
               )

      assert res["object"] == "list"
      assert is_list(res["data"])
    end

    test "lists with pagination" do
      client = Mock.client(&Mock.respond(&1, :fine_tuning_jobs))
      assert {:ok, res} = Mistral.list_fine_tuning_jobs(client, page: 0, page_size: 10)

      assert res["object"] == "list"
      assert is_list(res["data"])
    end

    test "handles API errors" do
      client = Mock.client(&Mock.respond(&1, 401))

      assert {:error, %Mistral.APIError{} = error} = Mistral.list_fine_tuning_jobs(client)

      assert error.status == 401
      assert error.type == "unauthorized"
    end
  end

  describe "get_fine_tuning_job/2" do
    test "retrieves a fine-tuning job by ID" do
      client = Mock.client(&Mock.respond(&1, :fine_tuning_job_detailed))
      assert {:ok, res} = Mistral.get_fine_tuning_job(client, "ft-abc123")

      assert res["id"] == "ft-abc123"
      assert res["object"] == "fine_tuning.job"
      assert res["status"] == "RUNNING"
      assert is_list(res["events"])
      assert is_list(res["checkpoints"])
    end

    test "handles job not found" do
      client = Mock.client(&Mock.respond(&1, 404))

      assert {:error, %Mistral.APIError{} = error} =
               Mistral.get_fine_tuning_job(client, "nonexistent-job-id")

      assert error.status == 404
      assert error.type == "not_found"
    end
  end

  describe "cancel_fine_tuning_job/2" do
    test "cancels a fine-tuning job" do
      client = Mock.client(&Mock.respond(&1, :fine_tuning_job_cancelled))
      assert {:ok, res} = Mistral.cancel_fine_tuning_job(client, "ft-abc123")

      assert res["id"] == "ft-abc123"
      assert res["status"] == "CANCELLATION_REQUESTED"
    end

    test "handles job not found" do
      client = Mock.client(&Mock.respond(&1, 404))

      assert {:error, %Mistral.APIError{} = error} =
               Mistral.cancel_fine_tuning_job(client, "nonexistent-job-id")

      assert error.status == 404
      assert error.type == "not_found"
    end
  end

  describe "start_fine_tuning_job/2" do
    test "starts a fine-tuning job" do
      client = Mock.client(&Mock.respond(&1, :fine_tuning_job_started))
      assert {:ok, res} = Mistral.start_fine_tuning_job(client, "ft-abc123")

      assert res["id"] == "ft-abc123"
      assert res["status"] == "STARTED"
    end

    test "handles job not found" do
      client = Mock.client(&Mock.respond(&1, 404))

      assert {:error, %Mistral.APIError{} = error} =
               Mistral.start_fine_tuning_job(client, "nonexistent-job-id")

      assert error.status == 404
      assert error.type == "not_found"
    end
  end

  describe "update_fine_tuned_model/3" do
    test "updates name and description" do
      client = Mock.client(&Mock.respond(&1, :ft_model_updated))

      assert {:ok, res} =
               Mistral.update_fine_tuned_model(
                 client,
                 "ft:open-mistral-7b:my-model:abc123",
                 name: "Updated Model Name",
                 description: "Updated description"
               )

      assert res["id"] == "ft:open-mistral-7b:my-model:abc123"
      assert res["name"] == "Updated Model Name"
      assert res["description"] == "Updated description"
    end

    test "updates only name" do
      client = Mock.client(&Mock.respond(&1, :ft_model_updated))

      assert {:ok, res} =
               Mistral.update_fine_tuned_model(
                 client,
                 "ft:open-mistral-7b:my-model:abc123",
                 name: "Updated Model Name"
               )

      assert res["id"] == "ft:open-mistral-7b:my-model:abc123"
    end

    test "handles model not found" do
      client = Mock.client(&Mock.respond(&1, 404))

      assert {:error, %Mistral.APIError{} = error} =
               Mistral.update_fine_tuned_model(
                 client,
                 "nonexistent-model-id",
                 name: "New Name"
               )

      assert error.status == 404
      assert error.type == "not_found"
    end
  end

  describe "archive_fine_tuned_model/2" do
    test "archives a fine-tuned model" do
      client = Mock.client(&Mock.respond(&1, :ft_model_archived))

      assert {:ok, res} =
               Mistral.archive_fine_tuned_model(client, "ft:open-mistral-7b:my-model:abc123")

      assert res["id"] == "ft:open-mistral-7b:my-model:abc123"
      assert res["archived"] == true
    end

    test "handles model not found" do
      client = Mock.client(&Mock.respond(&1, 404))

      assert {:error, %Mistral.APIError{} = error} =
               Mistral.archive_fine_tuned_model(client, "nonexistent-model-id")

      assert error.status == 404
      assert error.type == "not_found"
    end
  end

  describe "unarchive_fine_tuned_model/2" do
    test "unarchives a fine-tuned model" do
      client = Mock.client(&Mock.respond(&1, :ft_model_unarchived))

      assert {:ok, res} =
               Mistral.unarchive_fine_tuned_model(client, "ft:open-mistral-7b:my-model:abc123")

      assert res["id"] == "ft:open-mistral-7b:my-model:abc123"
      assert res["archived"] == false
    end

    test "handles model not found" do
      client = Mock.client(&Mock.respond(&1, 404))

      assert {:error, %Mistral.APIError{} = error} =
               Mistral.unarchive_fine_tuned_model(client, "nonexistent-model-id")

      assert error.status == 404
      assert error.type == "not_found"
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

  describe "delete_model/2" do
    test "deletes a model by ID" do
      client = Mock.client(&Mock.respond(&1, :model_deleted))
      assert {:ok, res} = Mistral.delete_model(client, "ft:open-mistral-7b:my-model:abc123")

      assert res["id"] == "ft:open-mistral-7b:my-model:abc123"
      assert res["deleted"] == true
    end

    test "handles model not found" do
      client = Mock.client(&Mock.respond(&1, 404))

      assert {:error, %Mistral.APIError{} = error} =
               Mistral.delete_model(client, "nonexistent-model-id")

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
