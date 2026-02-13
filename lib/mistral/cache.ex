defmodule Mistral.Cache do
  import Bitwise

  @moduledoc """
  Optional response caching for Mistral API requests.

  Implements a `Req` plugin that caches successful responses in ETS to reduce
  redundant API calls. Caching is applied selectively — only deterministic,
  non-streaming endpoints are cached.

  ## Cached endpoints

  - `GET` requests (models, files, agents)
  - Deterministic `POST` endpoints: `/embeddings`, `/classifications`,
    `/chat/classifications`, `/moderations`, `/chat/moderations`, `/ocr`

  ## Skipped requests

  - Streaming requests (where `into` option is set)
  - Non-deterministic `POST` endpoints (`/chat/completions`, `/fim/completions`,
    `/agents/completions`)
  - Mutation endpoints (`PUT`, `PATCH`, `DELETE`, non-cacheable `POST`)
  - Error responses (non-2xx)

  ## Usage

  Caching is enabled through `Mistral.init/2`:

      client = Mistral.init("api_key", cache: true)
      client = Mistral.init("api_key", cache: true, cache_ttl: 600_000)
      client = Mistral.init("api_key", cache: true, cache_table: :my_cache)

  ## TTL

  Entries expire lazily on read. Use `sweep/2` for bulk cleanup of expired entries.
  Default TTL is 5 minutes (300,000 ms).

  ## ETS table

  The cache uses a named ETS table (default `:mistral_cache`) with
  `read_concurrency` and `write_concurrency` enabled. The table is created
  lazily on first use and owned by a long-lived process.
  """

  @default_ttl 300_000
  @default_table :mistral_cache

  @cacheable_post_paths ~w(
    /embeddings
    /classifications
    /chat/classifications
    /moderations
    /chat/moderations
    /ocr
  )

  # -- Public API --

  @doc """
  Attaches the cache plugin to a `Req.Request`.

  ## Options

    * `:cache_ttl` - Time-to-live in milliseconds. Defaults to `#{@default_ttl}`.
    * `:cache_table` - ETS table name. Defaults to `:#{@default_table}`.
  """
  @spec attach(Req.Request.t(), keyword()) :: Req.Request.t()
  def attach(request, opts \\ []) do
    ttl = Keyword.get(opts, :cache_ttl, @default_ttl)
    table = Keyword.get(opts, :cache_table, @default_table)

    request
    |> Req.Request.put_private(:cache_ttl, ttl)
    |> Req.Request.put_private(:cache_table, table)
    |> Req.Request.prepend_request_steps(cache_request: &cache_request/1)
    |> Req.Request.append_response_steps(cache_response: &cache_response/1)
  end

  @doc """
  Deletes all entries from the cache table.
  """
  @spec clear(atom()) :: :ok
  def clear(table \\ @default_table) do
    if table_exists?(table) do
      :ets.delete_all_objects(table)
    end

    :ok
  end

  @doc """
  Deletes cache entries whose URL contains the given `pattern` substring.

  Returns the number of entries deleted.
  """
  @spec invalidate(String.t(), atom()) :: non_neg_integer()
  def invalidate(pattern, table \\ @default_table) do
    if table_exists?(table) do
      entries = :ets.tab2list(table)

      Enum.count(entries, fn {key, _body, _ts, url} ->
        if String.contains?(url, pattern) do
          :ets.delete(table, key)
          true
        else
          false
        end
      end)
    else
      0
    end
  end

  @doc """
  Returns cache statistics.

  ## Return value

      %{size: non_neg_integer(), memory_bytes: non_neg_integer()}
  """
  @spec stats(atom()) :: %{size: non_neg_integer(), memory_bytes: non_neg_integer()}
  def stats(table \\ @default_table) do
    if table_exists?(table) do
      info = :ets.info(table)
      %{size: info[:size], memory_bytes: info[:memory] * :erlang.system_info(:wordsize)}
    else
      %{size: 0, memory_bytes: 0}
    end
  end

  @doc """
  Removes expired entries from the cache. Returns the number of entries deleted.
  """
  @spec sweep(non_neg_integer(), atom()) :: non_neg_integer()
  def sweep(ttl \\ @default_ttl, table \\ @default_table) do
    if table_exists?(table) do
      now = System.monotonic_time(:millisecond)
      entries = :ets.tab2list(table)

      Enum.count(entries, fn {key, _body, inserted_at, _url} ->
        if now - inserted_at > ttl do
          :ets.delete(table, key)
          true
        else
          false
        end
      end)
    else
      0
    end
  end

  # -- Req Plugin Steps --

  defp cache_request(request) do
    table = request.private[:cache_table]
    ttl = request.private[:cache_ttl]
    method = request.method
    url = build_url(request)

    if cacheable?(method, url, request) do
      ensure_table!(table)
      key = cache_key(method, url, request.options[:json] || request.body)

      case :ets.lookup(table, key) do
        [{^key, body, inserted_at, _url}] ->
          if System.monotonic_time(:millisecond) - inserted_at <= ttl do
            response = %Req.Response{status: 200, body: body}
            Req.Request.halt(request, response)
          else
            :ets.delete(table, key)
            Req.Request.put_private(request, :cache_key, {key, url})
          end

        [] ->
          Req.Request.put_private(request, :cache_key, {key, url})
      end
    else
      request
    end
  end

  defp cache_response({request, response}) do
    case request.private[:cache_key] do
      {key, url} when response.status in 200..299 ->
        table = request.private[:cache_table]
        now = System.monotonic_time(:millisecond)
        :ets.insert(table, {key, response.body, now, url})
        {request, response}

      _ ->
        {request, response}
    end
  end

  # -- Cacheability --

  defp cacheable?(:get, _url, request), do: !streaming?(request)

  defp cacheable?(:post, url, request) do
    !streaming?(request) && cacheable_post_path?(url)
  end

  defp cacheable?(_method, _url, _request), do: false

  defp streaming?(request), do: request.options[:into] != nil

  defp cacheable_post_path?(url) do
    Enum.any?(@cacheable_post_paths, &String.ends_with?(url, &1))
  end

  # -- Cache Key --

  defp cache_key(method, url, body) do
    :erlang.phash2({method, url, body}, 1 <<< 32)
  end

  # -- URL Helpers --

  defp build_url(request) do
    uri = Req.Request.get_option(request, :base_url, "") |> URI.parse()
    url = request.url |> URI.parse()

    merged =
      %URI{uri | path: Path.join(uri.path || "/", url.path || "/")}
      |> URI.to_string()

    merged
  end

  # -- ETS Table Management --

  defp ensure_table!(table) do
    unless table_exists?(table) do
      try do
        spawn_table_owner(table)
      rescue
        ArgumentError -> :ok
      end
    end
  end

  defp spawn_table_owner(table) do
    parent = self()
    ref = make_ref()

    pid =
      spawn(fn ->
        try do
          :ets.new(table, [
            :named_table,
            :public,
            :set,
            read_concurrency: true,
            write_concurrency: true
          ])
        rescue
          ArgumentError -> :ok
        end

        send(parent, ref)
        # Keep the process alive to own the table
        Process.sleep(:infinity)
      end)

    # Ensure the process stays alive
    Process.link(pid)
    Process.unlink(pid)

    receive do
      ^ref -> :ok
    after
      5_000 -> :ok
    end
  end

  defp table_exists?(table) do
    :ets.whereis(table) != :undefined
  end
end
