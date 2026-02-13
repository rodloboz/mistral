defmodule Mistral.Streaming do
  @moduledoc """
  Utility functions for working with streaming responses.

  Provides stream transformation, content extraction, and multiplexing
  utilities for streams returned by `Mistral.chat/2`, `Mistral.fim/2`,
  `Mistral.agent_completion/2`, and the Conversations API when called with
  `stream: true`.

  All functions auto-detect the chunk format:

    * **Chat-style** (chat, FIM, agent): content at
      `chunk["choices"][0]["delta"]["content"]`, usage at `chunk["usage"]`

    * **Conversation-style**: content at `chunk["content"]` when
      `chunk["object"] == "message.output.delta"`, usage at `chunk["usage"]`
      when `chunk["object"] == "conversation.response.done"`

  Lazy functions return a new stream without consuming the input.
  Eager functions consume the entire stream and return a value.

  ## Examples

      # Collect all content from a chat stream
      {:ok, stream} = Mistral.chat(client,
        model: "mistral-small-latest",
        messages: [%{role: "user", content: "Hi"}],
        stream: true
      )
      Mistral.Streaming.collect_content(stream)
      #=> "Hello! How can I help you?"

      # Print content as it arrives, then get the usage
      {:ok, stream} = Mistral.chat(client,
        model: "mistral-small-latest",
        messages: [%{role: "user", content: "Hi"}],
        stream: true
      )
      stream
      |> Mistral.Streaming.each_content(&IO.write/1)
      |> Mistral.Streaming.extract_usage()
      #=> %{"prompt_tokens" => 10, "completion_tokens" => 20, "total_tokens" => 30}
  """

  @doc """
  Concatenates all content deltas from a stream into a single string.

  Consumes the entire stream (eager).

  ## Examples

      iex> stream = [
      ...>   %{"choices" => [%{"delta" => %{"content" => "Hello"}}]},
      ...>   %{"choices" => [%{"delta" => %{"content" => " world"}}]}
      ...> ]
      iex> Mistral.Streaming.collect_content(stream)
      "Hello world"
  """
  @spec collect_content(Enumerable.t()) :: String.t()
  def collect_content(stream) do
    reduce_content(stream, "", fn content, acc -> acc <> content end)
  end

  @doc """
  Builds a complete response map from a stream, matching the shape of
  a non-streaming API response.

  For chat-style streams, returns a map with `"choices"` containing a
  `"message"` (not `"delta"`), the `"object"` set to `"chat.completion"`,
  and `"usage"` if present.

  For conversation-style streams, returns a map with `"object"` set to
  `"conversation.response"`, an `"outputs"` list, and `"usage"`.

  Consumes the entire stream (eager).

  ## Examples

      iex> stream = [
      ...>   %{"id" => "cmpl-1", "object" => "chat.completion.chunk", "model" => "m",
      ...>     "choices" => [%{"index" => 0, "delta" => %{"role" => "assistant"},
      ...>       "finish_reason" => nil}]},
      ...>   %{"id" => "cmpl-1", "object" => "chat.completion.chunk", "model" => "m",
      ...>     "choices" => [%{"index" => 0, "delta" => %{"content" => "Hi"},
      ...>       "finish_reason" => "stop"}],
      ...>     "usage" => %{"prompt_tokens" => 5, "total_tokens" => 6}}
      ...> ]
      iex> resp = Mistral.Streaming.accumulate_response(stream)
      iex> resp["choices"] |> hd() |> get_in(["message", "content"])
      "Hi"
  """
  @spec accumulate_response(Enumerable.t()) :: map()
  def accumulate_response(stream) do
    initial = %{format: nil, content: "", usage: nil, meta: %{}, finish_reason: nil, role: nil}

    result =
      Enum.reduce(stream, initial, fn chunk, acc ->
        format = acc.format || detect_format(chunk)
        content_delta = extract_content(chunk) || ""
        usage = extract_chunk_usage(chunk) || acc.usage
        finish_reason = extract_finish_reason(chunk) || acc.finish_reason
        role = extract_role(chunk) || acc.role
        meta = merge_meta(acc.meta, chunk, format)

        %{
          acc
          | format: format,
            content: acc.content <> content_delta,
            usage: usage,
            finish_reason: finish_reason,
            role: role,
            meta: meta
        }
      end)

    build_response(result)
  end

  @doc """
  Invokes `fun` for each content delta as a side effect, passing all
  chunks through unchanged.

  Returns a new stream (lazy).

  ## Examples

      iex> stream = [%{"choices" => [%{"delta" => %{"content" => "Hi"}}]}]
      iex> stream |> Mistral.Streaming.each_content(&IO.write/1) |> Enum.to_list()
      [%{"choices" => [%{"delta" => %{"content" => "Hi"}}]}]
  """
  @spec each_content(Enumerable.t(), (String.t() -> any())) :: Enumerable.t()
  def each_content(stream, fun) when is_function(fun, 1) do
    Stream.each(stream, fn chunk ->
      case extract_content(chunk) do
        nil -> :ok
        content -> fun.(content)
      end
    end)
  end

  @doc """
  Extracts token usage information from a stream.

  Returns the last `"usage"` map found in the stream, or `nil` if none
  is present. Usage typically appears in the final chunk.

  Consumes the entire stream (eager).

  ## Examples

      iex> stream = [
      ...>   %{"choices" => [%{"delta" => %{"content" => "Hi"}}]},
      ...>   %{"choices" => [%{"delta" => %{"content" => "!"}},
      ...>     %{"usage" => %{"prompt_tokens" => 5, "total_tokens" => 7}}]}
      ...> ]
      iex> Mistral.Streaming.extract_usage(stream)
      nil
  """
  @spec extract_usage(Enumerable.t()) :: map() | nil
  def extract_usage(stream) do
    Enum.reduce(stream, nil, fn chunk, acc ->
      extract_chunk_usage(chunk) || acc
    end)
  end

  @doc """
  Transforms content deltas in place using the given function.

  Non-content chunks pass through unchanged.

  Returns a new stream (lazy).

  ## Examples

      iex> stream = [%{"choices" => [%{"delta" => %{"content" => "hello"}}]}]
      iex> stream |> Mistral.Streaming.map_content(&String.upcase/1) |> Enum.to_list()
      [%{"choices" => [%{"delta" => %{"content" => "HELLO"}}]}]
  """
  @spec map_content(Enumerable.t(), (String.t() -> String.t())) :: Enumerable.t()
  def map_content(stream, fun) when is_function(fun, 1) do
    Stream.map(stream, fn chunk ->
      case extract_content(chunk) do
        nil -> chunk
        content -> put_content(chunk, fun.(content))
      end
    end)
  end

  @doc """
  Accumulates a value over content deltas from a stream.

  Calls `fun.(content, acc)` for each chunk that contains content,
  skipping non-content chunks.

  Consumes the entire stream (eager).

  ## Examples

      iex> stream = [
      ...>   %{"choices" => [%{"delta" => %{"content" => "hello"}}]},
      ...>   %{"choices" => [%{"delta" => %{"content" => " world"}}]}
      ...> ]
      iex> Mistral.Streaming.reduce_content(stream, [], fn content, acc -> [content | acc] end)
      [" world", "hello"]
  """
  @spec reduce_content(Enumerable.t(), acc, (String.t(), acc -> acc)) :: acc when acc: term()
  def reduce_content(stream, acc, fun) when is_function(fun, 2) do
    Enum.reduce(stream, acc, fn chunk, acc ->
      case extract_content(chunk) do
        nil -> acc
        content -> fun.(content, acc)
      end
    end)
  end

  @doc """
  Filters chunks based on their content delta.

  Keeps chunks where `fun.(content)` returns truthy. Non-content chunks
  (e.g. role-only or usage-only) always pass through.

  Returns a new stream (lazy).

  ## Examples

      iex> stream = [
      ...>   %{"choices" => [%{"delta" => %{"content" => "keep"}}]},
      ...>   %{"choices" => [%{"delta" => %{"content" => ""}}]},
      ...>   %{"choices" => [%{"delta" => %{"role" => "assistant"}}]}
      ...> ]
      iex> stream |> Mistral.Streaming.filter_content(&(&1 != "")) |> Enum.to_list()
      [
        %{"choices" => [%{"delta" => %{"content" => "keep"}}]},
        %{"choices" => [%{"delta" => %{"role" => "assistant"}}]}
      ]
  """
  @spec filter_content(Enumerable.t(), (String.t() -> boolean())) :: Enumerable.t()
  def filter_content(stream, fun) when is_function(fun, 1) do
    Stream.filter(stream, fn chunk ->
      case extract_content(chunk) do
        nil -> true
        content -> fun.(content)
      end
    end)
  end

  @doc """
  Sends a copy of each chunk to the given PID, passing all chunks
  through unchanged.

  Chunks are sent as `{:stream_chunk, chunk}` messages.

  Returns a new stream (lazy).

  ## Examples

      iex> stream = [%{"choices" => [%{"delta" => %{"content" => "Hi"}}]}]
      iex> stream |> Mistral.Streaming.tee(self()) |> Enum.to_list()
      iex> receive do {:stream_chunk, chunk} -> chunk end
      %{"choices" => [%{"delta" => %{"content" => "Hi"}}]}
  """
  @spec tee(Enumerable.t(), pid()) :: Enumerable.t()
  def tee(stream, pid) when is_pid(pid) do
    Stream.each(stream, fn chunk ->
      send(pid, {:stream_chunk, chunk})
    end)
  end

  @doc """
  Merges multiple concurrent streams into a single stream.

  Chunks from all input streams are interleaved in arrival order.
  The merged stream completes when all input streams have been consumed.

  Each input stream is consumed concurrently in a separate process.

  Returns a new stream (lazy).

  ## Examples

      iex> s1 = [%{"choices" => [%{"delta" => %{"content" => "a"}}]}]
      iex> s2 = [%{"choices" => [%{"delta" => %{"content" => "b"}}]}]
      iex> chunks = Mistral.Streaming.merge([s1, s2]) |> Enum.to_list()
      iex> length(chunks)
      2
  """
  @spec merge([Enumerable.t()]) :: Enumerable.t()
  def merge(streams) when is_list(streams) do
    Stream.resource(
      fn ->
        parent = self()
        ref = make_ref()

        Enum.each(streams, fn stream ->
          spawn_link(fn ->
            Enum.each(stream, fn chunk ->
              send(parent, {ref, {:chunk, chunk}})
            end)

            send(parent, {ref, :done})
          end)
        end)

        {ref, length(streams), 0}
      end,
      fn {ref, total, done} = acc ->
        if done >= total do
          {:halt, acc}
        else
          receive do
            {^ref, {:chunk, chunk}} ->
              {[chunk], {ref, total, done}}

            {^ref, :done} ->
              {[], {ref, total, done + 1}}
          after
            30_000 -> {:halt, acc}
          end
        end
      end,
      fn _acc -> :ok end
    )
  end

  # -- Private helpers --

  defp extract_content(%{"choices" => [%{"delta" => %{"content" => content}} | _]}), do: content
  defp extract_content(%{"object" => "message.output.delta", "content" => content}), do: content
  defp extract_content(_), do: nil

  defp extract_chunk_usage(%{"usage" => usage}) when is_map(usage), do: usage
  defp extract_chunk_usage(_), do: nil

  defp extract_finish_reason(%{"choices" => [%{"finish_reason" => reason} | _]})
       when is_binary(reason),
       do: reason

  defp extract_finish_reason(_), do: nil

  defp extract_role(%{"choices" => [%{"delta" => %{"role" => role}} | _]}), do: role
  defp extract_role(_), do: nil

  defp put_content(%{"choices" => [choice | rest]} = chunk, new_content) do
    delta = Map.put(choice["delta"], "content", new_content)
    choice = Map.put(choice, "delta", delta)
    Map.put(chunk, "choices", [choice | rest])
  end

  defp put_content(%{"object" => "message.output.delta"} = chunk, new_content) do
    Map.put(chunk, "content", new_content)
  end

  defp put_content(chunk, _new_content), do: chunk

  defp detect_format(%{"choices" => _}), do: :chat
  defp detect_format(%{"object" => "message.output.delta"}), do: :conversation
  defp detect_format(%{"object" => "conversation.response" <> _}), do: :conversation
  defp detect_format(_), do: nil

  defp merge_meta(meta, chunk, :chat) do
    meta
    |> maybe_put("id", chunk["id"])
    |> maybe_put("model", chunk["model"])
    |> maybe_put("created", chunk["created"])
  end

  defp merge_meta(meta, chunk, :conversation) do
    maybe_put(meta, "conversation_id", chunk["conversation_id"])
  end

  defp merge_meta(meta, _chunk, _format), do: meta

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put_new(map, key, value)

  defp build_response(%{format: :chat} = result) do
    response =
      result.meta
      |> Map.put("object", "chat.completion")
      |> Map.put("choices", [
        %{
          "index" => 0,
          "message" => %{
            "role" => result.role || "assistant",
            "content" => result.content
          },
          "finish_reason" => result.finish_reason
        }
      ])

    if result.usage do
      Map.put(response, "usage", result.usage)
    else
      response
    end
  end

  defp build_response(%{format: :conversation} = result) do
    response =
      result.meta
      |> Map.put("object", "conversation.response")
      |> Map.put("outputs", [
        %{
          "type" => "message.output",
          "content" => result.content,
          "role" => "assistant"
        }
      ])

    if result.usage do
      Map.put(response, "usage", result.usage)
    else
      response
    end
  end

  defp build_response(result) do
    %{"content" => result.content, "usage" => result.usage}
  end
end
