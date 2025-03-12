defmodule Mistral do
  @version Keyword.fetch!(Mix.Project.config(), :version)
  @moduledoc """
  Client for the Mistral AI API.

  This library provides a simple and convenient way to integrate with Mistral's
  API, allowing you to use their powerful language models in your Elixir applications.
  """

  defstruct [:req]

  @typedoc "Client struct"
  @type client() :: %__MODULE__{
          req: Req.Request.t()
        }

  @typedoc "Client response"
  @type response() ::
          {:ok, map() | Enumerable.t() | Task.t()}
          | {:error, term()}

  @typedoc false
  @type req_response() ::
          {:ok, Req.Response.t() | Task.t() | Enumerable.t()}
          | {:error, term()}

  @default_req_opts [
    base_url: "https://api.mistral.ai/v1",
    headers: [
      {"user-agent", "mistral-ex/#{@version}"}
    ],
    receive_timeout: 60_000
  ]

  @doc """
  Creates a new Mistral API client using the API key set in your application's config.

  ```elixir
  config :mistral, :api_key, "your-api-key"
  ```

  If given, a keyword list of options will be passed to `Req.new/1`.
  """
  @spec init() :: client()
  def init(), do: init([])

  @spec init(keyword()) :: client()
  def init(opts) when is_list(opts) do
    api_key = Application.fetch_env!(:mistral, :api_key)
    init(api_key, opts)
  end

  @doc """
  Creates a new Mistral API client with the given API key.

  Optionally, a keyword list of options can be passed through to `Req.new/1`.
  """
  @spec init(String.t(), keyword()) :: client()
  def init(api_key, opts \\ []) when is_binary(api_key) do
    {headers, opts} = Keyword.pop(opts, :headers, [])

    req =
      @default_req_opts
      |> Keyword.merge(opts)
      |> Req.new()
      |> Req.Request.put_header("authorization", "Bearer #{api_key}")
      |> Req.Request.put_headers(headers)

    struct(__MODULE__, req: req)
  end

  @doc """
  Chat with a Mistral model. Send messages and get a completion from the model.

  ## Options

  - `:model` - The model to use for generating the response (required)
  - `:messages` - List of messages in the conversation (required)
  - `:temperature` - Controls randomness (0.0 to 1.0)
  - `:max_tokens` - Maximum number of tokens to generate
  - `:stream` - When true, returns a stream of partial response chunks
  - `:tools` - List of tools available to the model. Each tool must be a map with:
    * `:type` set to "function"
    * `:function` containing function details
  - `:tool_choice` - How to choose tools

  ## Examples

      iex> Mistral.chat(client, [
      ...>   model: "mistral-small-latest",
      ...>   messages: [
      ...>     %{role: "user", content: "Write a haiku."}
      ...>   ]
      ...> ])
      {:ok, %{"choices" => [%{"message" => %{"content" => "Nature's whisper soft..."}}], ...}}

      # Stream the response
      iex> {:ok, stream} = Mistral.chat(client, [
      ...>   model: "mistral-small-latest",
      ...>   messages: [%{role: "user", content: "Write a haiku."}],
      ...>   stream: true
      ...> ])
      iex> Enum.to_list(stream)
      [%{"choices" => [%{"delta" => ...}]}, ...]

      ## Tool Example

      iex> Mistral.chat(client, [
      ...>   model: "mistral-large-latest",
      ...>   messages: [%{role: "user", content: "What is the weather?"}],
      ...>   tools: [
      ...>     %{
      ...>       type: "function",
      ...>       function: %{
      ...>         name: "get_weather",
      ...>         description: "Fetches current weather",
      ...>         parameters: %{type: "object", properties: %{}}
      ...>       }
      ...>     }
      ...>   ],
      ...>   tool_choice: "auto"
      ...> ])
  """
  @spec chat(client(), keyword()) :: response()
  def chat(%__MODULE__{} = client, params) when is_list(params) do
    {stream_opt, params} = Keyword.pop(params, :stream, false)

    params =
      if Keyword.has_key?(params, :tools) do
        Keyword.update(params, :tools, [], fn tools ->
          Enum.map(tools, fn
            %{type: "function", function: _} = tool -> tool
            _ -> raise ArgumentError, "Tools must have type 'function' and a 'function' key"
          end)
        end)
      else
        params
      end

    if stream_opt do
      params = Keyword.put(params, :stream, true)
      dest = if is_pid(stream_opt), do: stream_opt, else: self()

      task =
        Task.async(fn ->
          client
          |> req(:post, "/chat/completions",
            json: Enum.into(params, %{}),
            into: stream_handler(dest)
          )
          |> res()
        end)

      case stream_opt do
        true -> {:ok, Stream.resource(fn -> task end, &stream_next/1, &stream_end/1)}
        _ -> {:ok, task}
      end
    else
      client
      |> req(:post, "/chat/completions", json: Enum.into(params, %{}))
      |> res()
    end
  end

  @spec stream_handler(pid()) :: fun()
  defp stream_handler(pid) do
    fn {:data, data}, {req, res} ->
      # Split the SSE data into events
      data
      |> String.split("data: ")
      |> Enum.filter(&(&1 != ""))
      |> Enum.map(fn chunk ->
        chunk = String.trim(chunk)

        if chunk != "" do
          case Jason.decode(chunk) do
            {:ok, parsed} ->
              Process.send(pid, {self(), {:data, parsed}}, [])
              parsed

            _ ->
              nil
          end
        end
      end)
      |> Enum.filter(&(&1 != nil))
      |> Enum.reduce(res, fn parsed, res ->
        stream_merge(res, parsed)
      end)
      |> then(fn updated_res -> {:cont, {req, updated_res}} end)
    end
  end

  defp stream_merge(%Req.Response{body: body} = res, chunk) do
    # For initial empty body, just set it to the chunk
    if body == "" or body == nil or body == %{} do
      %{res | body: chunk}
    else
      # For subsequent chunks, merge appropriately
      # For SSE, we don't merge, each chunk is complete
      %{res | body: chunk}
    end
  end

  defp stream_next(%Task{pid: pid, ref: ref} = task) do
    receive do
      {^pid, {:data, data}} ->
        {[data], task}

      {^ref, {:ok, %Req.Response{status: status}}} when status in 200..299 ->
        {:halt, task}

      {^ref, {:ok, resp}} when not is_struct(resp, Req.Response) ->
        {:halt, task}

      {^ref, {:ok, resp}} ->
        raise "HTTP Error: #{inspect(resp)}"

      {^ref, {:error, error}} ->
        raise error

      {:DOWN, _ref, _, _pid, _reason} ->
        {:halt, task}
    after
      30_000 -> {:halt, task}
    end
  end

  defp stream_end(%Task{ref: ref}), do: Process.demonitor(ref, [:flush])

  @spec req(client(), atom(), Req.url(), keyword()) :: req_response()
  defp req(%__MODULE__{req: req}, method, url, opts) do
    opts = Keyword.merge(opts, method: method, url: url)
    Req.request(req, opts)
  end

  @spec res(req_response()) :: response()
  defp res({:ok, %Req.Response{status: status, body: ""}}) when status in 200..299,
    do: {:ok, %{}}

  defp res({:ok, %Req.Response{status: status, body: body}}) when status in 200..299,
    do: {:ok, body}

  defp res({:ok, resp}), do: {:error, resp}
  defp res({:error, error}), do: {:error, error}
end
