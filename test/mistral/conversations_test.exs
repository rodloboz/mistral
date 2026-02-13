defmodule Mistral.ConversationsTest do
  use ExUnit.Case, async: true

  alias Mistral.Conversations

  # ── Fixtures ──────────────────────────────────────────────────────────

  @response %{
    "object" => "conversation.response",
    "conversation_id" => "conv_abc123",
    "outputs" => [
      %{
        "type" => "message.output",
        "id" => "entry_out_001",
        "content" => "Hello! How can I help you today?",
        "role" => "assistant",
        "model" => "mistral-large-latest"
      }
    ],
    "usage" => %{
      "prompt_tokens" => 10,
      "completion_tokens" => 12,
      "total_tokens" => 22
    }
  }

  @response_with_tool_outputs %{
    "object" => "conversation.response",
    "conversation_id" => "conv_abc123",
    "outputs" => [
      %{
        "type" => "tool.call",
        "id" => "tc_001",
        "name" => "search",
        "arguments" => "{\"query\": \"weather\"}"
      },
      %{
        "type" => "message.output",
        "id" => "entry_out_002",
        "content" => "The weather is sunny.",
        "role" => "assistant",
        "model" => "mistral-large-latest"
      }
    ],
    "usage" => %{
      "prompt_tokens" => 15,
      "completion_tokens" => 8,
      "total_tokens" => 23
    }
  }

  @empty_response %{
    "object" => "conversation.response",
    "conversation_id" => "conv_abc123",
    "outputs" => []
  }

  @history %{
    "entries" => [
      %{
        "type" => "message.input",
        "id" => "entry_in_001",
        "content" => "Hello!",
        "role" => "user"
      },
      %{
        "type" => "message.output",
        "id" => "entry_out_001",
        "content" => "Hi there!",
        "role" => "assistant",
        "model" => "mistral-large-latest"
      },
      %{
        "type" => "message.input",
        "id" => "entry_in_002",
        "content" => "What is the weather?",
        "role" => "user"
      },
      %{
        "type" => "message.output",
        "id" => "entry_out_002",
        "content" => "It's sunny today.",
        "role" => "assistant",
        "model" => "mistral-large-latest"
      }
    ]
  }

  @history_with_tool_entries %{
    "entries" => [
      %{
        "type" => "message.input",
        "id" => "entry_in_001",
        "content" => "Search for weather",
        "role" => "user"
      },
      %{
        "type" => "tool.call",
        "id" => "tc_001",
        "name" => "search",
        "arguments" => "{\"query\": \"weather\"}"
      },
      %{
        "type" => "function.result",
        "id" => "fr_001",
        "tool_call_id" => "tc_001",
        "result" => "Sunny, 72F"
      },
      %{
        "type" => "message.output",
        "id" => "entry_out_001",
        "content" => "The weather is sunny and 72F.",
        "role" => "assistant",
        "model" => "mistral-large-latest"
      }
    ]
  }

  @messages_response %{
    "messages" => [
      %{"role" => "user", "content" => "Hello!"},
      %{"role" => "assistant", "content" => "Hi there!"},
      %{"role" => "user", "content" => "What is the weather?"},
      %{"role" => "assistant", "content" => "It's sunny today."}
    ]
  }

  # ── Group 1: Response Extraction ──────────────────────────────────────

  describe "extract_content/1" do
    test "extracts content from the first message.output" do
      assert Conversations.extract_content(@response) == "Hello! How can I help you today?"
    end

    test "skips non-message.output entries" do
      assert Conversations.extract_content(@response_with_tool_outputs) ==
               "The weather is sunny."
    end

    test "returns nil for empty outputs" do
      assert Conversations.extract_content(@empty_response) == nil
    end

    test "returns nil for missing outputs key" do
      assert Conversations.extract_content(%{}) == nil
    end

    test "returns nil for outputs with no message.output type" do
      response = %{
        "outputs" => [%{"type" => "tool.call", "id" => "tc1"}]
      }

      assert Conversations.extract_content(response) == nil
    end
  end

  describe "extract_outputs/1" do
    test "extracts full outputs list" do
      outputs = Conversations.extract_outputs(@response)
      assert length(outputs) == 1
      assert hd(outputs)["type"] == "message.output"
    end

    test "returns multiple outputs including tool calls" do
      outputs = Conversations.extract_outputs(@response_with_tool_outputs)
      assert length(outputs) == 2
    end

    test "returns empty list for empty outputs" do
      assert Conversations.extract_outputs(@empty_response) == []
    end

    test "returns empty list for missing outputs key" do
      assert Conversations.extract_outputs(%{}) == []
    end
  end

  describe "extract_conversation_id/1" do
    test "extracts from response" do
      assert Conversations.extract_conversation_id(@response) == "conv_abc123"
    end

    test "extracts from any map with conversation_id" do
      assert Conversations.extract_conversation_id(%{"conversation_id" => "conv_xyz"}) ==
               "conv_xyz"
    end

    test "returns nil for missing key" do
      assert Conversations.extract_conversation_id(%{}) == nil
    end
  end

  describe "extract_usage/1" do
    test "extracts usage from response" do
      usage = Conversations.extract_usage(@response)
      assert usage["prompt_tokens"] == 10
      assert usage["completion_tokens"] == 12
      assert usage["total_tokens"] == 22
    end

    test "returns nil when usage is missing" do
      assert Conversations.extract_usage(@empty_response) == nil
    end

    test "returns nil for empty map" do
      assert Conversations.extract_usage(%{}) == nil
    end
  end

  describe "extract_entries/1" do
    test "extracts entries from history" do
      entries = Conversations.extract_entries(@history)
      assert length(entries) == 4
      assert hd(entries)["type"] == "message.input"
    end

    test "returns empty list for missing entries key" do
      assert Conversations.extract_entries(%{}) == []
    end
  end

  describe "extract_messages/1" do
    test "extracts messages from messages response" do
      messages = Conversations.extract_messages(@messages_response)
      assert length(messages) == 4
      assert hd(messages)["role"] == "user"
    end

    test "returns empty list for missing messages key" do
      assert Conversations.extract_messages(%{}) == []
    end
  end

  # ── Group 2: Format Conversion ────────────────────────────────────────

  describe "entries_to_messages/1" do
    test "converts message entries to chat messages" do
      entries = Conversations.extract_entries(@history)
      messages = Conversations.entries_to_messages(entries)

      assert messages == [
               %{"role" => "user", "content" => "Hello!"},
               %{"role" => "assistant", "content" => "Hi there!"},
               %{"role" => "user", "content" => "What is the weather?"},
               %{"role" => "assistant", "content" => "It's sunny today."}
             ]
    end

    test "filters out non-message types" do
      entries = Conversations.extract_entries(@history_with_tool_entries)
      messages = Conversations.entries_to_messages(entries)

      assert length(messages) == 2
      assert hd(messages)["role"] == "user"
      assert List.last(messages)["role"] == "assistant"
    end

    test "returns empty list for empty entries" do
      assert Conversations.entries_to_messages([]) == []
    end
  end

  describe "history_to_chat_messages/1" do
    test "converts history directly to chat messages" do
      messages = Conversations.history_to_chat_messages(@history)

      assert messages == [
               %{"role" => "user", "content" => "Hello!"},
               %{"role" => "assistant", "content" => "Hi there!"},
               %{"role" => "user", "content" => "What is the weather?"},
               %{"role" => "assistant", "content" => "It's sunny today."}
             ]
    end

    test "filters tool entries from history" do
      messages = Conversations.history_to_chat_messages(@history_with_tool_entries)
      assert length(messages) == 2
    end

    test "handles history with no entries key" do
      assert Conversations.history_to_chat_messages(%{}) == []
    end
  end

  describe "response_to_message/1" do
    test "converts response to assistant message" do
      assert Conversations.response_to_message(@response) == %{
               "role" => "assistant",
               "content" => "Hello! How can I help you today?"
             }
    end

    test "returns nil for empty outputs" do
      assert Conversations.response_to_message(@empty_response) == nil
    end

    test "returns nil for missing outputs" do
      assert Conversations.response_to_message(%{}) == nil
    end
  end

  # ── Group 3: Context Window Management ────────────────────────────────

  describe "last_entries/2" do
    test "returns last n entries" do
      entries = Conversations.extract_entries(@history)
      result = Conversations.last_entries(entries, 2)

      assert length(result) == 2
      assert hd(result)["id"] == "entry_in_002"
      assert List.last(result)["id"] == "entry_out_002"
    end

    test "returns all entries when n exceeds length" do
      entries = Conversations.extract_entries(@history)
      result = Conversations.last_entries(entries, 10)
      assert length(result) == 4
    end

    test "returns empty list for empty input" do
      assert Conversations.last_entries([], 5) == []
    end
  end

  describe "last_messages/2" do
    test "returns last n messages" do
      messages = Conversations.extract_messages(@messages_response)
      result = Conversations.last_messages(messages, 2)

      assert result == [
               %{"role" => "user", "content" => "What is the weather?"},
               %{"role" => "assistant", "content" => "It's sunny today."}
             ]
    end

    test "returns all messages when n exceeds length" do
      messages = Conversations.extract_messages(@messages_response)
      result = Conversations.last_messages(messages, 100)
      assert length(result) == 4
    end
  end

  describe "sliding_window/2" do
    test "aligns to message.input boundary" do
      entries = Conversations.extract_entries(@history)
      # Take last 3, but align to message.input
      result = Conversations.sliding_window(entries, 3)

      assert length(result) == 2
      assert hd(result)["type"] == "message.input"
      assert hd(result)["id"] == "entry_in_002"
    end

    test "returns full window when already aligned" do
      entries = Conversations.extract_entries(@history)
      result = Conversations.sliding_window(entries, 4)

      assert length(result) == 4
      assert hd(result)["type"] == "message.input"
    end

    test "returns full window when n is 2 and last 2 start with input" do
      entries = Conversations.extract_entries(@history)
      result = Conversations.sliding_window(entries, 2)

      assert length(result) == 2
      assert hd(result)["id"] == "entry_in_002"
    end

    test "drops leading entries until message.input found" do
      entries = [
        %{"type" => "message.output", "id" => "out1"},
        %{"type" => "message.output", "id" => "out2"},
        %{"type" => "message.input", "id" => "in1"},
        %{"type" => "message.output", "id" => "out3"}
      ]

      result = Conversations.sliding_window(entries, 4)
      assert length(result) == 2
      assert hd(result)["id"] == "in1"
    end

    test "returns empty list when no message.input in window" do
      entries = [
        %{"type" => "message.output", "id" => "out1"},
        %{"type" => "message.output", "id" => "out2"}
      ]

      assert Conversations.sliding_window(entries, 2) == []
    end

    test "returns empty list for empty input" do
      assert Conversations.sliding_window([], 5) == []
    end

    test "handles tool entries in the window" do
      entries = Conversations.extract_entries(@history_with_tool_entries)
      # Last 3: tool.call, function.result, message.output — no message.input
      result = Conversations.sliding_window(entries, 3)
      assert result == []
    end
  end

  # ── Group 4: Entry Navigation ─────────────────────────────────────────

  describe "entry_ids/1" do
    test "extracts all entry IDs" do
      entries = Conversations.extract_entries(@history)
      ids = Conversations.entry_ids(entries)
      assert ids == ["entry_in_001", "entry_out_001", "entry_in_002", "entry_out_002"]
    end

    test "returns empty list for empty entries" do
      assert Conversations.entry_ids([]) == []
    end
  end

  describe "find_entry/2" do
    test "finds entry by ID" do
      entries = Conversations.extract_entries(@history)
      entry = Conversations.find_entry(entries, "entry_out_001")

      assert entry["id"] == "entry_out_001"
      assert entry["content"] == "Hi there!"
    end

    test "returns nil for unknown ID" do
      entries = Conversations.extract_entries(@history)
      assert Conversations.find_entry(entries, "nonexistent") == nil
    end

    test "returns nil for empty entries" do
      assert Conversations.find_entry([], "e1") == nil
    end
  end

  describe "last_output_entry/1" do
    test "returns the last message.output entry" do
      entries = Conversations.extract_entries(@history)
      entry = Conversations.last_output_entry(entries)

      assert entry["id"] == "entry_out_002"
      assert entry["content"] == "It's sunny today."
    end

    test "returns nil when no output entries exist" do
      entries = [%{"type" => "message.input", "id" => "in1"}]
      assert Conversations.last_output_entry(entries) == nil
    end

    test "returns nil for empty list" do
      assert Conversations.last_output_entry([]) == nil
    end

    test "finds output among tool entries" do
      entries = Conversations.extract_entries(@history_with_tool_entries)
      entry = Conversations.last_output_entry(entries)

      assert entry["id"] == "entry_out_001"
      assert entry["type"] == "message.output"
    end
  end

  describe "last_input_entry/1" do
    test "returns the last message.input entry" do
      entries = Conversations.extract_entries(@history)
      entry = Conversations.last_input_entry(entries)

      assert entry["id"] == "entry_in_002"
      assert entry["content"] == "What is the weather?"
    end

    test "returns nil when no input entries exist" do
      entries = [%{"type" => "message.output", "id" => "out1"}]
      assert Conversations.last_input_entry(entries) == nil
    end

    test "returns nil for empty list" do
      assert Conversations.last_input_entry([]) == nil
    end
  end

  describe "entries_by_type/2" do
    test "filters by message.input type" do
      entries = Conversations.extract_entries(@history)
      inputs = Conversations.entries_by_type(entries, "message.input")

      assert length(inputs) == 2
      assert Enum.all?(inputs, &(&1["type"] == "message.input"))
    end

    test "filters by tool.call type" do
      entries = Conversations.extract_entries(@history_with_tool_entries)
      tool_calls = Conversations.entries_by_type(entries, "tool.call")

      assert length(tool_calls) == 1
      assert hd(tool_calls)["name"] == "search"
    end

    test "returns empty list when type not found" do
      entries = Conversations.extract_entries(@history)
      assert Conversations.entries_by_type(entries, "tool.call") == []
    end

    test "returns empty list for empty entries" do
      assert Conversations.entries_by_type([], "message.input") == []
    end
  end

  describe "outputs_by_type/2" do
    test "filters outputs by message.output type" do
      outputs = Conversations.extract_outputs(@response_with_tool_outputs)
      messages = Conversations.outputs_by_type(outputs, "message.output")

      assert length(messages) == 1
      assert hd(messages)["content"] == "The weather is sunny."
    end

    test "filters outputs by tool.call type" do
      outputs = Conversations.extract_outputs(@response_with_tool_outputs)
      tool_calls = Conversations.outputs_by_type(outputs, "tool.call")

      assert length(tool_calls) == 1
      assert hd(tool_calls)["name"] == "search"
    end

    test "returns empty list when type not found" do
      outputs = Conversations.extract_outputs(@response)
      assert Conversations.outputs_by_type(outputs, "tool.call") == []
    end

    test "returns empty list for empty outputs" do
      assert Conversations.outputs_by_type([], "message.output") == []
    end
  end

  # ── Group 5: Input Builders ───────────────────────────────────────────

  describe "build_entry_input/2" do
    test "builds a user message input" do
      assert Conversations.build_entry_input("user", "Hello!") == %{
               "type" => "message.input",
               "role" => "user",
               "content" => "Hello!"
             }
    end

    test "builds a system message input" do
      assert Conversations.build_entry_input("system", "You are helpful.") == %{
               "type" => "message.input",
               "role" => "system",
               "content" => "You are helpful."
             }
    end
  end

  describe "build_function_result_input/2" do
    test "builds a function result entry" do
      assert Conversations.build_function_result_input("call_123", "42") == %{
               "type" => "function.result",
               "tool_call_id" => "call_123",
               "result" => "42"
             }
    end
  end

  describe "build_inputs/1" do
    test "converts strings to user message inputs" do
      result = Conversations.build_inputs(["Hello!", "Follow up"])

      assert result == [
               %{"type" => "message.input", "role" => "user", "content" => "Hello!"},
               %{"type" => "message.input", "role" => "user", "content" => "Follow up"}
             ]
    end

    test "passes maps through unchanged" do
      map = %{"type" => "function.result", "tool_call_id" => "c1", "result" => "ok"}
      assert Conversations.build_inputs([map]) == [map]
    end

    test "handles mixed strings and maps" do
      map = %{"type" => "function.result", "tool_call_id" => "c1", "result" => "ok"}
      result = Conversations.build_inputs(["Hello!", map])

      assert result == [
               %{"type" => "message.input", "role" => "user", "content" => "Hello!"},
               map
             ]
    end

    test "returns empty list for empty input" do
      assert Conversations.build_inputs([]) == []
    end

    test "raises ArgumentError for invalid elements" do
      assert_raise ArgumentError, ~r/expected a string or map/, fn ->
        Conversations.build_inputs([123])
      end
    end

    test "raises ArgumentError for atom elements" do
      assert_raise ArgumentError, ~r/expected a string or map/, fn ->
        Conversations.build_inputs([:hello])
      end
    end
  end
end
