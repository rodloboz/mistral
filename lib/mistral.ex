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
  """
  @spec chat(client(), keyword()) :: response()
  def chat(%__MODULE__{} = client, params) when is_list(params) do
    client
    |> req(:post, "/chat/completions", json: Enum.into(params, %{}))
    |> res()
  end

  @spec req(client(), atom(), Req.url(), keyword()) :: req_response()
  defp req(%__MODULE__{req: req}, method, url, opts) do
    opts = Keyword.merge(opts, method: method, url: url)
    Req.request(req, opts)
  end

  @spec res(req_response()) :: response()
  defp res({:ok, %{status: status, body: ""} = response}) when status in 200..299,
    do: {:ok, response.body}

  defp res({:ok, %{status: status, body: body}}) when status in 200..299,
    do: {:ok, body}

  defp res({:ok, resp}),
    do: {:error, resp}

  defp res({:error, error}), do: {:error, error}
end
