defmodule Mistral.CacheTest do
  use ExUnit.Case, async: true

  alias Mistral.{Cache, Mock}

  defp unique_table do
    :"test_cache_#{System.unique_integer([:positive])}"
  end

  defp cached_client(plug, table, opts \\ []) do
    {cache_ttl, req_opts} = Keyword.pop(opts, :cache_ttl, 300_000)
    client = Mock.client(plug, req_opts)
    req = Cache.attach(client.req, cache_table: table, cache_ttl: cache_ttl)
    %{client | req: req}
  end

  describe "attach/2" do
    test "registers options with correct defaults" do
      req = Req.new() |> Cache.attach()

      assert req.private[:cache_ttl] == 300_000
      assert req.private[:cache_table] == :mistral_cache
    end

    test "accepts custom TTL and table" do
      table = unique_table()
      req = Req.new() |> Cache.attach(cache_ttl: 60_000, cache_table: table)

      assert req.private[:cache_ttl] == 60_000
      assert req.private[:cache_table] == table
    end
  end

  describe "cache hit" do
    test "second identical embed/2 call skips HTTP" do
      table = unique_table()
      counter = :counters.new(1, [:atomics])

      client =
        cached_client(
          fn conn ->
            :counters.add(counter, 1, 1)
            Mock.respond(conn, :embedding)
          end,
          table
        )

      assert {:ok, %{"data" => _}} =
               Mistral.embed(client,
                 model: "mistral-embed",
                 input: ["Hello world"]
               )

      assert {:ok, %{"data" => _}} =
               Mistral.embed(client,
                 model: "mistral-embed",
                 input: ["Hello world"]
               )

      assert :counters.get(counter, 1) == 1
    end
  end

  describe "cache miss" do
    test "different params make separate HTTP calls" do
      table = unique_table()
      counter = :counters.new(1, [:atomics])

      client =
        cached_client(
          fn conn ->
            :counters.add(counter, 1, 1)
            Mock.respond(conn, :embedding)
          end,
          table
        )

      assert {:ok, _} =
               Mistral.embed(client,
                 model: "mistral-embed",
                 input: ["Hello world"]
               )

      assert {:ok, _} =
               Mistral.embed(client,
                 model: "mistral-embed",
                 input: ["Different text"]
               )

      assert :counters.get(counter, 1) == 2
    end
  end

  describe "TTL expiration" do
    test "expired entries are re-fetched from server" do
      table = unique_table()
      counter = :counters.new(1, [:atomics])

      client =
        cached_client(
          fn conn ->
            :counters.add(counter, 1, 1)
            Mock.respond(conn, :embedding)
          end,
          table,
          cache_ttl: 1
        )

      assert {:ok, _} =
               Mistral.embed(client,
                 model: "mistral-embed",
                 input: ["Hello world"]
               )

      Process.sleep(5)

      assert {:ok, _} =
               Mistral.embed(client,
                 model: "mistral-embed",
                 input: ["Hello world"]
               )

      assert :counters.get(counter, 1) == 2
    end
  end

  describe "streaming bypass" do
    test "chat with stream: true does not populate cache" do
      table = unique_table()
      counter = :counters.new(1, [:atomics])

      client =
        cached_client(
          fn conn ->
            :counters.add(counter, 1, 1)
            Mock.stream(conn, :chat_completion)
          end,
          table
        )

      assert {:ok, stream} =
               Mistral.chat(client,
                 model: "mistral-small-latest",
                 messages: [%{role: "user", content: "Hello"}],
                 stream: true
               )

      _chunks = Enum.to_list(stream)

      assert Cache.stats(table).size == 0
    end
  end

  describe "non-deterministic bypass" do
    test "chat/2 (non-streaming) is not cached" do
      table = unique_table()
      counter = :counters.new(1, [:atomics])

      client =
        cached_client(
          fn conn ->
            :counters.add(counter, 1, 1)
            Mock.respond(conn, :chat_completion)
          end,
          table
        )

      assert {:ok, _} =
               Mistral.chat(client,
                 model: "mistral-small-latest",
                 messages: [%{role: "user", content: "Hello"}]
               )

      assert {:ok, _} =
               Mistral.chat(client,
                 model: "mistral-small-latest",
                 messages: [%{role: "user", content: "Hello"}]
               )

      assert :counters.get(counter, 1) == 2
      assert Cache.stats(table).size == 0
    end
  end

  describe "error bypass" do
    test "500 responses are not cached" do
      table = unique_table()
      counter = :counters.new(1, [:atomics])

      client =
        cached_client(
          fn conn ->
            :counters.add(counter, 1, 1)
            Mock.respond(conn, 500)
          end,
          table,
          retry: false
        )

      assert {:error, _} =
               Mistral.embed(client,
                 model: "mistral-embed",
                 input: ["Hello world"]
               )

      assert {:error, _} =
               Mistral.embed(client,
                 model: "mistral-embed",
                 input: ["Hello world"]
               )

      assert :counters.get(counter, 1) == 2
      assert Cache.stats(table).size == 0
    end
  end

  describe "clear/1" do
    test "empties the table" do
      table = unique_table()
      counter = :counters.new(1, [:atomics])

      client =
        cached_client(
          fn conn ->
            :counters.add(counter, 1, 1)
            Mock.respond(conn, :embedding)
          end,
          table
        )

      assert {:ok, _} =
               Mistral.embed(client,
                 model: "mistral-embed",
                 input: ["Hello world"]
               )

      assert Cache.stats(table).size == 1
      Cache.clear(table)
      assert Cache.stats(table).size == 0
    end
  end

  describe "sweep/2" do
    test "removes only expired entries" do
      table = unique_table()
      counter = :counters.new(1, [:atomics])

      client =
        cached_client(
          fn conn ->
            :counters.add(counter, 1, 1)
            Mock.respond(conn, :embedding)
          end,
          table
        )

      # Create first entry
      assert {:ok, _} =
               Mistral.embed(client,
                 model: "mistral-embed",
                 input: ["First"]
               )

      Process.sleep(10)

      # Create second entry
      assert {:ok, _} =
               Mistral.embed(client,
                 model: "mistral-embed",
                 input: ["Second"]
               )

      assert Cache.stats(table).size == 2

      # Sweep with a TTL that only expires the first entry
      deleted = Cache.sweep(5, table)
      assert deleted == 1
      assert Cache.stats(table).size == 1
    end
  end

  describe "invalidate/2" do
    test "removes entries matching URL pattern" do
      table = unique_table()

      client =
        cached_client(
          fn conn ->
            Mock.respond(conn, :embedding)
          end,
          table
        )

      assert {:ok, _} =
               Mistral.embed(client,
                 model: "mistral-embed",
                 input: ["Hello"]
               )

      assert Cache.stats(table).size == 1

      deleted = Cache.invalidate("/embeddings", table)
      assert deleted == 1
      assert Cache.stats(table).size == 0
    end

    test "does not remove non-matching entries" do
      table = unique_table()

      client =
        cached_client(
          fn conn ->
            Mock.respond(conn, :embedding)
          end,
          table
        )

      assert {:ok, _} =
               Mistral.embed(client,
                 model: "mistral-embed",
                 input: ["Hello"]
               )

      deleted = Cache.invalidate("/models", table)
      assert deleted == 0
      assert Cache.stats(table).size == 1
    end
  end

  describe "stats/1" do
    test "returns correct size and memory info" do
      table = unique_table()

      client =
        cached_client(
          fn conn ->
            Mock.respond(conn, :embedding)
          end,
          table
        )

      assert Cache.stats(table) == %{size: 0, memory_bytes: 0}

      assert {:ok, _} =
               Mistral.embed(client,
                 model: "mistral-embed",
                 input: ["Hello"]
               )

      stats = Cache.stats(table)
      assert stats.size == 1
      assert stats.memory_bytes > 0
    end
  end

  describe "init integration" do
    test "cache: true in client options enables caching end-to-end" do
      table = unique_table()
      counter = :counters.new(1, [:atomics])

      plug = fn conn ->
        :counters.add(counter, 1, 1)
        Mock.respond(conn, :embedding)
      end

      # Build a client the same way init/2 would, but with a plug for testing
      req =
        Req.new(plug: plug)
        |> Cache.attach(cache_table: table)

      client = struct(Mistral, req: req)

      assert {:ok, _} =
               Mistral.embed(client,
                 model: "mistral-embed",
                 input: ["Hello"]
               )

      assert {:ok, _} =
               Mistral.embed(client,
                 model: "mistral-embed",
                 input: ["Hello"]
               )

      assert :counters.get(counter, 1) == 1
    end
  end
end
