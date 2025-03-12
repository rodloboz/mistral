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
    test "generates a response for a given prompt" do
      client = Mock.client(&Mock.respond(&1, :chat_completion))

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
  end
end
