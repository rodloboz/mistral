defmodule Mistral.Conversations do
  @moduledoc """
  Utility functions for working with conversation responses and history.

  Provides response extraction, format conversion, context window management,
  entry navigation, and input builders for data returned by the Conversations API
  (`Mistral.create_conversation/2`, `Mistral.append_conversation/3`,
  `Mistral.get_conversation_history/2`, `Mistral.get_conversation_messages/2`,
  and `Mistral.restart_conversation/3`).

  All functions are pure — they operate on raw maps and lists, with no state
  or API calls.

  ## Examples

      # Extract assistant text from a conversation response
      iex> response = %{"outputs" => [%{"type" => "message.output", "content" => "Hi!"}]}
      iex> Mistral.Conversations.extract_content(response)
      "Hi!"

      # Convert history entries to chat-compatible messages
      iex> history = %{"entries" => [
      ...>   %{"type" => "message.input", "role" => "user", "content" => "Hello"},
      ...>   %{"type" => "message.output", "role" => "assistant", "content" => "Hi!"}
      ...> ]}
      iex> Mistral.Conversations.history_to_chat_messages(history)
      [%{"role" => "user", "content" => "Hello"}, %{"role" => "assistant", "content" => "Hi!"}]
  """

  @typedoc ~S'A conversation API response map containing `"outputs"` and optionally `"usage"`.'
  @type response() :: map()

  @typedoc ~S'A conversation history map containing `"entries"`.'
  @type history() :: map()

  @typedoc ~S'A conversation messages response map containing `"messages"`.'
  @type messages_response() :: map()

  @typedoc ~S'A single history entry with `"type"`, `"id"`, `"role"`, and `"content"`.'
  @type entry() :: map()

  @typedoc ~S'A chat-style message with `"role"` and `"content"`.'
  @type message() :: map()

  @typedoc "A single output from a conversation response."
  @type output() :: map()

  # ── Group 1: Response Extraction ──────────────────────────────────────

  @doc """
  Extracts the assistant text content from a conversation response.

  Looks for the first output with `"type" => "message.output"` and returns
  its `"content"`. Returns `nil` if no message output is found.

  ## Examples

      iex> response = %{"outputs" => [%{"type" => "message.output", "content" => "Hello!"}]}
      iex> Mistral.Conversations.extract_content(response)
      "Hello!"

      iex> Mistral.Conversations.extract_content(%{"outputs" => []})
      nil
  """
  @spec extract_content(response()) :: String.t() | nil
  def extract_content(%{"outputs" => outputs}) do
    case Enum.find(outputs, &(&1["type"] == "message.output")) do
      %{"content" => content} -> content
      _ -> nil
    end
  end

  def extract_content(_), do: nil

  @doc """
  Extracts the full outputs list from a conversation response.

  Returns an empty list if no `"outputs"` key is present.

  ## Examples

      iex> response = %{"outputs" => [%{"type" => "message.output", "content" => "Hi"}]}
      iex> Mistral.Conversations.extract_outputs(response)
      [%{"type" => "message.output", "content" => "Hi"}]

      iex> Mistral.Conversations.extract_outputs(%{})
      []
  """
  @spec extract_outputs(response()) :: [output()]
  def extract_outputs(%{"outputs" => outputs}), do: outputs
  def extract_outputs(_), do: []

  @doc """
  Extracts the conversation ID from any conversation map.

  Works with responses, history, conversation objects, and any map
  containing a `"conversation_id"` key.

  ## Examples

      iex> Mistral.Conversations.extract_conversation_id(%{"conversation_id" => "conv_abc123"})
      "conv_abc123"

      iex> Mistral.Conversations.extract_conversation_id(%{})
      nil
  """
  @spec extract_conversation_id(map()) :: String.t() | nil
  def extract_conversation_id(%{"conversation_id" => id}), do: id
  def extract_conversation_id(_), do: nil

  @doc """
  Extracts token usage information from a conversation response.

  Returns the `"usage"` map, or `nil` if not present.

  ## Examples

      iex> response = %{"usage" => %{"prompt_tokens" => 10, "total_tokens" => 22}}
      iex> Mistral.Conversations.extract_usage(response)
      %{"prompt_tokens" => 10, "total_tokens" => 22}

      iex> Mistral.Conversations.extract_usage(%{})
      nil
  """
  @spec extract_usage(response()) :: map() | nil
  def extract_usage(%{"usage" => usage}) when is_map(usage), do: usage
  def extract_usage(_), do: nil

  @doc """
  Extracts entries from a conversation history response.

  Returns an empty list if no `"entries"` key is present.

  ## Examples

      iex> history = %{"entries" => [%{"type" => "message.input", "id" => "e1"}]}
      iex> Mistral.Conversations.extract_entries(history)
      [%{"type" => "message.input", "id" => "e1"}]

      iex> Mistral.Conversations.extract_entries(%{})
      []
  """
  @spec extract_entries(history()) :: [entry()]
  def extract_entries(%{"entries" => entries}), do: entries
  def extract_entries(_), do: []

  @doc """
  Extracts messages from a conversation messages response.

  Returns an empty list if no `"messages"` key is present.

  ## Examples

      iex> response = %{"messages" => [%{"role" => "user", "content" => "Hi"}]}
      iex> Mistral.Conversations.extract_messages(response)
      [%{"role" => "user", "content" => "Hi"}]

      iex> Mistral.Conversations.extract_messages(%{})
      []
  """
  @spec extract_messages(messages_response()) :: [message()]
  def extract_messages(%{"messages" => messages}), do: messages
  def extract_messages(_), do: []

  # ── Group 2: Format Conversion ────────────────────────────────────────

  @doc """
  Converts history entries to chat-style messages.

  Filters entries to only `"message.input"` and `"message.output"` types,
  then maps each to `%{"role" => ..., "content" => ...}`.

  ## Examples

      iex> entries = [
      ...>   %{"type" => "message.input", "role" => "user", "content" => "Hello"},
      ...>   %{"type" => "tool.call", "id" => "tc1"},
      ...>   %{"type" => "message.output", "role" => "assistant", "content" => "Hi!"}
      ...> ]
      iex> Mistral.Conversations.entries_to_messages(entries)
      [%{"role" => "user", "content" => "Hello"}, %{"role" => "assistant", "content" => "Hi!"}]
  """
  @spec entries_to_messages([entry()]) :: [message()]
  def entries_to_messages(entries) when is_list(entries) do
    entries
    |> Enum.filter(&(&1["type"] in ["message.input", "message.output"]))
    |> Enum.map(&%{"role" => &1["role"], "content" => &1["content"]})
  end

  @doc """
  Converts a conversation history response to chat-compatible messages.

  Pipeline: extracts entries, filters to message types, converts to
  `%{"role" => ..., "content" => ...}` format.

  ## Examples

      iex> history = %{"entries" => [
      ...>   %{"type" => "message.input", "role" => "user", "content" => "Hello"},
      ...>   %{"type" => "message.output", "role" => "assistant", "content" => "Hi!"}
      ...> ]}
      iex> Mistral.Conversations.history_to_chat_messages(history)
      [%{"role" => "user", "content" => "Hello"}, %{"role" => "assistant", "content" => "Hi!"}]
  """
  @spec history_to_chat_messages(history()) :: [message()]
  def history_to_chat_messages(history) when is_map(history) do
    history |> extract_entries() |> entries_to_messages()
  end

  @doc """
  Converts a conversation response to a single assistant message.

  Returns `%{"role" => "assistant", "content" => ...}` from the first
  `"message.output"`, or `nil` if no message output is found.

  ## Examples

      iex> response = %{"outputs" => [%{"type" => "message.output", "content" => "Hello!"}]}
      iex> Mistral.Conversations.response_to_message(response)
      %{"role" => "assistant", "content" => "Hello!"}

      iex> Mistral.Conversations.response_to_message(%{"outputs" => []})
      nil
  """
  @spec response_to_message(response()) :: message() | nil
  def response_to_message(response) do
    case extract_content(response) do
      nil -> nil
      content -> %{"role" => "assistant", "content" => content}
    end
  end

  # ── Group 3: Context Window Management ────────────────────────────────

  @doc """
  Returns the last `n` entries from a list.

  ## Examples

      iex> entries = [%{"id" => "1"}, %{"id" => "2"}, %{"id" => "3"}]
      iex> Mistral.Conversations.last_entries(entries, 2)
      [%{"id" => "2"}, %{"id" => "3"}]
  """
  @spec last_entries([entry()], pos_integer()) :: [entry()]
  def last_entries(entries, n) when is_list(entries) and is_integer(n) and n > 0 do
    Enum.take(entries, -n)
  end

  @doc """
  Returns the last `n` messages from a list.

  ## Examples

      iex> messages = [%{"role" => "user"}, %{"role" => "assistant"}, %{"role" => "user"}]
      iex> Mistral.Conversations.last_messages(messages, 2)
      [%{"role" => "assistant"}, %{"role" => "user"}]
  """
  @spec last_messages([message()], pos_integer()) :: [message()]
  def last_messages(messages, n) when is_list(messages) and is_integer(n) and n > 0 do
    Enum.take(messages, -n)
  end

  @doc """
  Returns the last `n` entries, aligned to a `"message.input"` turn boundary.

  Takes up to `n` entries from the end, then drops any leading entries
  until a `"message.input"` entry is found, ensuring the window starts
  at a user turn.

  ## Examples

      iex> entries = [
      ...>   %{"type" => "message.input", "id" => "1"},
      ...>   %{"type" => "message.output", "id" => "2"},
      ...>   %{"type" => "message.input", "id" => "3"},
      ...>   %{"type" => "message.output", "id" => "4"}
      ...> ]
      iex> Mistral.Conversations.sliding_window(entries, 3)
      [%{"type" => "message.input", "id" => "3"}, %{"type" => "message.output", "id" => "4"}]
  """
  @spec sliding_window([entry()], pos_integer()) :: [entry()]
  def sliding_window(entries, n) when is_list(entries) and is_integer(n) and n > 0 do
    entries
    |> Enum.take(-n)
    |> Enum.drop_while(&(&1["type"] != "message.input"))
  end

  # ── Group 4: Entry Navigation ─────────────────────────────────────────

  @doc """
  Extracts all entry IDs from a list of entries.

  ## Examples

      iex> entries = [%{"id" => "e1"}, %{"id" => "e2"}]
      iex> Mistral.Conversations.entry_ids(entries)
      ["e1", "e2"]
  """
  @spec entry_ids([entry()]) :: [String.t()]
  def entry_ids(entries) when is_list(entries) do
    Enum.map(entries, & &1["id"])
  end

  @doc """
  Finds an entry by its ID.

  Returns `nil` if no entry with the given ID is found.

  ## Examples

      iex> entries = [%{"id" => "e1", "content" => "hello"}, %{"id" => "e2", "content" => "world"}]
      iex> Mistral.Conversations.find_entry(entries, "e2")
      %{"id" => "e2", "content" => "world"}

      iex> Mistral.Conversations.find_entry([], "e1")
      nil
  """
  @spec find_entry([entry()], String.t()) :: entry() | nil
  def find_entry(entries, id) when is_list(entries) and is_binary(id) do
    Enum.find(entries, &(&1["id"] == id))
  end

  @doc """
  Returns the last `"message.output"` entry from a list.

  Returns `nil` if no output entry is found.

  ## Examples

      iex> entries = [
      ...>   %{"type" => "message.input", "id" => "1"},
      ...>   %{"type" => "message.output", "id" => "2"},
      ...>   %{"type" => "message.input", "id" => "3"}
      ...> ]
      iex> Mistral.Conversations.last_output_entry(entries)
      %{"type" => "message.output", "id" => "2"}
  """
  @spec last_output_entry([entry()]) :: entry() | nil
  def last_output_entry(entries) when is_list(entries) do
    entries
    |> Enum.reverse()
    |> Enum.find(&(&1["type"] == "message.output"))
  end

  @doc """
  Returns the last `"message.input"` entry from a list.

  Returns `nil` if no input entry is found.

  ## Examples

      iex> entries = [
      ...>   %{"type" => "message.input", "id" => "1"},
      ...>   %{"type" => "message.output", "id" => "2"}
      ...> ]
      iex> Mistral.Conversations.last_input_entry(entries)
      %{"type" => "message.input", "id" => "1"}
  """
  @spec last_input_entry([entry()]) :: entry() | nil
  def last_input_entry(entries) when is_list(entries) do
    entries
    |> Enum.reverse()
    |> Enum.find(&(&1["type"] == "message.input"))
  end

  @doc """
  Filters entries by their `"type"` field.

  ## Examples

      iex> entries = [
      ...>   %{"type" => "message.input", "id" => "1"},
      ...>   %{"type" => "tool.call", "id" => "2"},
      ...>   %{"type" => "message.output", "id" => "3"}
      ...> ]
      iex> Mistral.Conversations.entries_by_type(entries, "tool.call")
      [%{"type" => "tool.call", "id" => "2"}]
  """
  @spec entries_by_type([entry()], String.t()) :: [entry()]
  def entries_by_type(entries, type) when is_list(entries) and is_binary(type) do
    Enum.filter(entries, &(&1["type"] == type))
  end

  @doc """
  Filters outputs by their `"type"` field.

  ## Examples

      iex> outputs = [
      ...>   %{"type" => "message.output", "content" => "Hi"},
      ...>   %{"type" => "tool.call", "name" => "search"}
      ...> ]
      iex> Mistral.Conversations.outputs_by_type(outputs, "tool.call")
      [%{"type" => "tool.call", "name" => "search"}]
  """
  @spec outputs_by_type([output()], String.t()) :: [output()]
  def outputs_by_type(outputs, type) when is_list(outputs) and is_binary(type) do
    Enum.filter(outputs, &(&1["type"] == type))
  end

  # ── Group 5: Input Builders ───────────────────────────────────────────

  @doc """
  Builds a message input entry map.

  ## Examples

      iex> Mistral.Conversations.build_entry_input("user", "Hello!")
      %{"type" => "message.input", "role" => "user", "content" => "Hello!"}
  """
  @spec build_entry_input(String.t(), String.t()) :: map()
  def build_entry_input(role, content) when is_binary(role) and is_binary(content) do
    %{"type" => "message.input", "role" => role, "content" => content}
  end

  @doc """
  Builds a function result input entry map.

  ## Examples

      iex> Mistral.Conversations.build_function_result_input("call_123", "42")
      %{"type" => "function.result", "tool_call_id" => "call_123", "result" => "42"}
  """
  @spec build_function_result_input(String.t(), String.t()) :: map()
  def build_function_result_input(tool_call_id, result)
      when is_binary(tool_call_id) and is_binary(result) do
    %{"type" => "function.result", "tool_call_id" => tool_call_id, "result" => result}
  end

  @doc """
  Converts a mixed list of inputs into entry maps.

  Strings are converted to user message inputs. Maps pass through unchanged.

  Raises `ArgumentError` if any element is not a string or map.

  ## Examples

      iex> Mistral.Conversations.build_inputs(["Hello!", %{"type" => "function.result", "tool_call_id" => "c1", "result" => "ok"}])
      [
        %{"type" => "message.input", "role" => "user", "content" => "Hello!"},
        %{"type" => "function.result", "tool_call_id" => "c1", "result" => "ok"}
      ]
  """
  @spec build_inputs([String.t() | map()]) :: [map()]
  def build_inputs(inputs) when is_list(inputs) do
    Enum.map(inputs, fn
      input when is_binary(input) -> build_entry_input("user", input)
      input when is_map(input) -> input
      other -> raise ArgumentError, "expected a string or map, got: #{inspect(other)}"
    end)
  end
end
