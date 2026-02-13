defmodule Mistral.StreamingTest do
  use ExUnit.Case, async: true

  alias Mistral.Streaming

  # Chat-style chunks (chat, FIM, agent)
  @chat_chunks [
    %{
      "id" => "cmpl-1",
      "object" => "chat.completion.chunk",
      "created" => 1_702_256_327,
      "model" => "mistral-small-latest",
      "choices" => [
        %{"index" => 0, "delta" => %{"role" => "assistant"}, "finish_reason" => nil}
      ]
    },
    %{
      "id" => "cmpl-1",
      "object" => "chat.completion.chunk",
      "created" => 1_702_256_327,
      "model" => "mistral-small-latest",
      "choices" => [
        %{"index" => 0, "delta" => %{"content" => "Hello"}, "finish_reason" => nil}
      ]
    },
    %{
      "id" => "cmpl-1",
      "object" => "chat.completion.chunk",
      "created" => 1_702_256_327,
      "model" => "mistral-small-latest",
      "choices" => [
        %{"index" => 0, "delta" => %{"content" => " world"}, "finish_reason" => "stop"}
      ],
      "usage" => %{"prompt_tokens" => 5, "completion_tokens" => 3, "total_tokens" => 8}
    }
  ]

  # Conversation-style chunks
  @conversation_chunks [
    %{
      "object" => "conversation.response.started",
      "conversation_id" => "conv_abc123",
      "created_at" => 1_702_256_327
    },
    %{
      "object" => "message.output.delta",
      "conversation_id" => "conv_abc123",
      "content" => "Hello"
    },
    %{
      "object" => "message.output.delta",
      "conversation_id" => "conv_abc123",
      "content" => " world"
    },
    %{
      "object" => "conversation.response.done",
      "conversation_id" => "conv_abc123",
      "usage" => %{"prompt_tokens" => 5, "completion_tokens" => 3, "total_tokens" => 8}
    }
  ]

  describe "collect_content/1" do
    test "concatenates chat-style content deltas" do
      assert Streaming.collect_content(@chat_chunks) == "Hello world"
    end

    test "concatenates conversation-style content deltas" do
      assert Streaming.collect_content(@conversation_chunks) == "Hello world"
    end

    test "returns empty string for empty stream" do
      assert Streaming.collect_content([]) == ""
    end

    test "skips non-content chunks" do
      chunks = [
        %{"choices" => [%{"delta" => %{"role" => "assistant"}}]},
        %{"choices" => [%{"delta" => %{"content" => "only"}}]}
      ]

      assert Streaming.collect_content(chunks) == "only"
    end
  end

  describe "accumulate_response/1" do
    test "builds chat-style response" do
      resp = Streaming.accumulate_response(@chat_chunks)

      assert resp["object"] == "chat.completion"
      assert resp["id"] == "cmpl-1"
      assert resp["model"] == "mistral-small-latest"
      assert resp["created"] == 1_702_256_327

      [choice] = resp["choices"]
      assert choice["index"] == 0
      assert choice["message"]["role"] == "assistant"
      assert choice["message"]["content"] == "Hello world"
      assert choice["finish_reason"] == "stop"

      assert resp["usage"] == %{
               "prompt_tokens" => 5,
               "completion_tokens" => 3,
               "total_tokens" => 8
             }
    end

    test "builds conversation-style response" do
      resp = Streaming.accumulate_response(@conversation_chunks)

      assert resp["object"] == "conversation.response"
      assert resp["conversation_id"] == "conv_abc123"

      [output] = resp["outputs"]
      assert output["type"] == "message.output"
      assert output["content"] == "Hello world"
      assert output["role"] == "assistant"

      assert resp["usage"] == %{
               "prompt_tokens" => 5,
               "completion_tokens" => 3,
               "total_tokens" => 8
             }
    end

    test "handles stream without usage" do
      chunks = [
        %{
          "id" => "cmpl-1",
          "object" => "chat.completion.chunk",
          "model" => "m",
          "choices" => [
            %{"index" => 0, "delta" => %{"content" => "Hi"}, "finish_reason" => "stop"}
          ]
        }
      ]

      resp = Streaming.accumulate_response(chunks)
      refute Map.has_key?(resp, "usage")
      assert resp["choices"] |> hd() |> get_in(["message", "content"]) == "Hi"
    end
  end

  describe "each_content/2" do
    test "invokes callback for chat-style content" do
      {:ok, agent} = Agent.start_link(fn -> [] end)

      result =
        @chat_chunks
        |> Streaming.each_content(fn content ->
          Agent.update(agent, fn state -> [content | state] end)
        end)
        |> Enum.to_list()

      # All chunks pass through unchanged
      assert result == @chat_chunks

      # Callback was invoked for content deltas
      collected = Agent.get(agent, &Enum.reverse/1)
      assert collected == ["Hello", " world"]
    end

    test "invokes callback for conversation-style content" do
      {:ok, agent} = Agent.start_link(fn -> [] end)

      @conversation_chunks
      |> Streaming.each_content(fn content ->
        Agent.update(agent, fn state -> [content | state] end)
      end)
      |> Enum.to_list()

      collected = Agent.get(agent, &Enum.reverse/1)
      assert collected == ["Hello", " world"]
    end
  end

  describe "extract_usage/1" do
    test "extracts usage from chat-style stream" do
      assert Streaming.extract_usage(@chat_chunks) == %{
               "prompt_tokens" => 5,
               "completion_tokens" => 3,
               "total_tokens" => 8
             }
    end

    test "extracts usage from conversation-style stream" do
      assert Streaming.extract_usage(@conversation_chunks) == %{
               "prompt_tokens" => 5,
               "completion_tokens" => 3,
               "total_tokens" => 8
             }
    end

    test "returns nil when no usage present" do
      chunks = [
        %{"choices" => [%{"delta" => %{"content" => "Hi"}}]}
      ]

      assert Streaming.extract_usage(chunks) == nil
    end
  end

  describe "map_content/2" do
    test "transforms chat-style content" do
      result =
        @chat_chunks
        |> Streaming.map_content(&String.upcase/1)
        |> Enum.to_list()

      contents =
        Enum.flat_map(result, fn
          %{"choices" => [%{"delta" => %{"content" => c}}]} -> [c]
          _ -> []
        end)

      assert contents == ["HELLO", " WORLD"]
    end

    test "transforms conversation-style content" do
      result =
        @conversation_chunks
        |> Streaming.map_content(&String.upcase/1)
        |> Enum.to_list()

      contents =
        Enum.flat_map(result, fn
          %{"object" => "message.output.delta", "content" => c} -> [c]
          _ -> []
        end)

      assert contents == ["HELLO", " WORLD"]
    end

    test "passes non-content chunks unchanged" do
      chunks = [
        %{"choices" => [%{"delta" => %{"role" => "assistant"}}]},
        %{"choices" => [%{"delta" => %{"content" => "hi"}}]}
      ]

      result =
        chunks
        |> Streaming.map_content(&String.upcase/1)
        |> Enum.to_list()

      assert hd(result) == %{"choices" => [%{"delta" => %{"role" => "assistant"}}]}
      assert List.last(result) == %{"choices" => [%{"delta" => %{"content" => "HI"}}]}
    end
  end

  describe "reduce_content/3" do
    test "accumulates chat-style content" do
      result =
        Streaming.reduce_content(@chat_chunks, [], fn content, acc ->
          [content | acc]
        end)

      assert Enum.reverse(result) == ["Hello", " world"]
    end

    test "accumulates conversation-style content" do
      result =
        Streaming.reduce_content(@conversation_chunks, 0, fn content, acc ->
          acc + String.length(content)
        end)

      assert result == 11
    end

    test "skips non-content chunks" do
      chunks = [
        %{"choices" => [%{"delta" => %{"role" => "assistant"}}]},
        %{"choices" => [%{"delta" => %{"content" => "a"}}]},
        %{"usage" => %{"total_tokens" => 5}},
        %{"choices" => [%{"delta" => %{"content" => "b"}}]}
      ]

      result = Streaming.reduce_content(chunks, "", fn c, acc -> acc <> c end)
      assert result == "ab"
    end
  end

  describe "filter_content/2" do
    test "filters chat-style chunks by content" do
      chunks = [
        %{"choices" => [%{"delta" => %{"role" => "assistant"}}]},
        %{"choices" => [%{"delta" => %{"content" => ""}}]},
        %{"choices" => [%{"delta" => %{"content" => "keep"}}]},
        %{"choices" => [%{"delta" => %{"content" => ""}}]}
      ]

      result =
        chunks
        |> Streaming.filter_content(&(&1 != ""))
        |> Enum.to_list()

      assert length(result) == 2

      # Non-content chunk passes through
      assert hd(result) == %{"choices" => [%{"delta" => %{"role" => "assistant"}}]}
      # Content chunk that matches passes through
      assert List.last(result) == %{"choices" => [%{"delta" => %{"content" => "keep"}}]}
    end

    test "filters conversation-style chunks by content" do
      chunks = [
        %{"object" => "conversation.response.started", "conversation_id" => "c1"},
        %{"object" => "message.output.delta", "content" => ""},
        %{"object" => "message.output.delta", "content" => "keep"},
        %{"object" => "conversation.response.done", "usage" => %{}}
      ]

      result =
        chunks
        |> Streaming.filter_content(&(&1 != ""))
        |> Enum.to_list()

      # started, "keep", done pass through; empty content filtered
      assert length(result) == 3
    end
  end

  describe "tee/2" do
    test "sends copies to a PID" do
      chunks = [
        %{"choices" => [%{"delta" => %{"content" => "a"}}]},
        %{"choices" => [%{"delta" => %{"content" => "b"}}]}
      ]

      result =
        chunks
        |> Streaming.tee(self())
        |> Enum.to_list()

      # Original chunks pass through
      assert result == chunks

      # Copies were sent
      assert_received {:stream_chunk, %{"choices" => [%{"delta" => %{"content" => "a"}}]}}
      assert_received {:stream_chunk, %{"choices" => [%{"delta" => %{"content" => "b"}}]}}
    end

    test "sends conversation-style chunks" do
      chunks = [
        %{"object" => "message.output.delta", "content" => "hi"}
      ]

      chunks
      |> Streaming.tee(self())
      |> Enum.to_list()

      assert_received {:stream_chunk, %{"object" => "message.output.delta", "content" => "hi"}}
    end
  end

  describe "merge/1" do
    test "merges multiple streams" do
      s1 = [
        %{"choices" => [%{"delta" => %{"content" => "a"}}]},
        %{"choices" => [%{"delta" => %{"content" => "b"}}]}
      ]

      s2 = [
        %{"choices" => [%{"delta" => %{"content" => "x"}}]},
        %{"choices" => [%{"delta" => %{"content" => "y"}}]}
      ]

      result = Streaming.merge([s1, s2]) |> Enum.to_list()

      assert length(result) == 4

      contents =
        Enum.map(result, fn %{"choices" => [%{"delta" => %{"content" => c}}]} -> c end)

      assert Enum.sort(contents) == ["a", "b", "x", "y"]
    end

    test "handles empty list of streams" do
      assert Streaming.merge([]) |> Enum.to_list() == []
    end

    test "handles single stream" do
      chunks = [%{"choices" => [%{"delta" => %{"content" => "only"}}]}]
      result = Streaming.merge([chunks]) |> Enum.to_list()
      assert result == chunks
    end

    test "merges conversation-style streams" do
      s1 = [%{"object" => "message.output.delta", "content" => "a"}]
      s2 = [%{"object" => "message.output.delta", "content" => "b"}]

      result = Streaming.merge([s1, s2]) |> Enum.to_list()
      assert length(result) == 2

      contents = Enum.map(result, & &1["content"])
      assert Enum.sort(contents) == ["a", "b"]
    end
  end

  describe "composability" do
    test "chain lazy operations then consume eagerly" do
      result =
        @chat_chunks
        |> Streaming.map_content(&String.upcase/1)
        |> Streaming.filter_content(&(&1 != ""))
        |> Streaming.collect_content()

      assert result == "HELLO WORLD"
    end

    test "each_content then extract_usage" do
      {:ok, agent} = Agent.start_link(fn -> [] end)

      usage =
        @chat_chunks
        |> Streaming.each_content(fn content ->
          Agent.update(agent, fn state -> [content | state] end)
        end)
        |> Streaming.extract_usage()

      assert usage == %{
               "prompt_tokens" => 5,
               "completion_tokens" => 3,
               "total_tokens" => 8
             }

      collected = Agent.get(agent, &Enum.reverse/1)
      assert collected == ["Hello", " world"]
    end

    test "tee and collect_content" do
      content =
        @chat_chunks
        |> Streaming.tee(self())
        |> Streaming.collect_content()

      assert content == "Hello world"
      assert_received {:stream_chunk, _}
    end
  end
end
