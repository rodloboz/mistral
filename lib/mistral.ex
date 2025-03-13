defmodule Mistral do
  @version Keyword.fetch!(Mix.Project.config(), :version)
  @moduledoc """
  ![GitHub CI](https://github.com/rodloboz/mistral/actions/workflows/all-checks-pass.yml/badge.svg)

  [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

  Client for the Mistral AI API.

  This library provides a simple and convenient way to integrate with Mistral's
  API, allowing you to use their powerful language models in your Elixir applications.

  ## Installation

  Add `mistral` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [
      {:mistral, "~> #{@version}"}
    ]
  end
  ```

  ## Configuration

  Set your Mistral API key in your config:

  ```elixir
  config :mistral, :api_key, "your_mistral_api_key"
  ```

  ## Usage Examples

  ### Chat Completion

  ```elixir
  {:ok, client} = Mistral.init("your_api_key")

  {:ok, response} = Mistral.chat(client,
    model: "mistral-small-latest",
    messages: [
      %{role: "user", content: "Write a haiku about elixir"}
    ]
  )
  ```
  """
  use Mistral.Schemas
  alias Mistral.APIError

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
          {:ok, Req.Response.t() | Task.t() | Enum.t()}
          | {:error, term()}

  @permissive_map {:map, {:or, [:atom, :string]}, :any}

  @default_req_opts [
    base_url: "https://api.mistral.ai/v1",
    headers: [
      {"user-agent",
       "mistral-ex/#{@version} (Elixir/#{System.version()}; OTP/#{System.otp_release()})"}
    ],
    receive_timeout: 60_000
  ]

  schema(:chat_message,
    role: [
      type: {:in, ["system", "user", "assistant", "tool"]},
      required: true,
      doc: "The role of the message, either `system`, `user`, `assistant` or `tool`."
    ],
    content: [
      type: {:or, [:string, {:list, @permissive_map}, nil]},
      doc: "The content of the message."
    ],
    tool_calls: [
      type: {:list, @permissive_map},
      doc: "*(optional)* Tool calls from the assistant that the model wants to use."
    ],
    tool_call_id: [
      type: :string,
      doc:
        "*(optional)* Required when `role` is 'tool'. ID of the tool call this message is responding to."
    ]
  )

  schema(:function_def,
    name: [
      type: :string,
      required: true,
      doc: "The name of the function to be called."
    ],
    description: [
      type: :string,
      doc: "*(optional)* A description of what the function does."
    ],
    parameters: [
      type: @permissive_map,
      required: true,
      doc: "The parameters the function accepts, described as a JSON Schema object."
    ]
  )

  schema(:tool_def,
    type: [
      type: {:in, ["function"]},
      required: true,
      doc: "The type of tool. Currently only 'function' is supported."
    ],
    function: [
      type: :map,
      required: true,
      keys: nested_schema(:function_def),
      doc: "The function definition."
    ]
  )

  schema(:chat,
    model: [
      type: :string,
      required: true,
      doc: "The model to use for generating the response."
    ],
    messages: [
      type: {:list, {:map, nested_schema(:chat_message)}},
      required: true,
      doc: "List of messages in the conversation."
    ],
    temperature: [
      type: :float,
      doc: "Controls randomness. Lower values are more deterministic (0.0 to 1.5)."
    ],
    top_p: [
      type: :float,
      default: 1.0,
      doc:
        "Controls diversity via nucleus sampling. Considers only tokens with the top_p probability mass."
    ],
    max_tokens: [
      type: :non_neg_integer,
      doc: "Maximum number of tokens to generate."
    ],
    stream: [
      type: {:or, [:boolean, :pid]},
      default: false,
      doc: "When true, returns a stream of partial response chunks."
    ],
    random_seed: [
      type: :non_neg_integer,
      doc: "Seed for deterministic results."
    ],
    tools: [
      type: {:list, {:map, nested_schema(:tool_def)}},
      doc: "List of tools available to the model."
    ],
    tool_choice: [
      type: {:or, [:string, @permissive_map]},
      doc: "Controls tool selection. Options: 'auto', 'any', 'none', or a specific tool."
    ],
    presence_penalty: [
      type: :float,
      default: 0.0,
      doc: "Penalizes repetition of tokens. Higher values reduce repetition."
    ],
    frequency_penalty: [
      type: :float,
      default: 0.0,
      doc: "Penalizes tokens based on their frequency. Higher values reduce repetition."
    ],
    safe_prompt: [
      type: :boolean,
      default: false,
      doc: "Whether to inject a safety prompt before all conversations."
    ]
  )

  schema(:embed,
    model: [
      type: :string,
      default: "mistral-embed",
      doc: "The model to use for generating embeddings."
    ],
    input: [
      type: {:or, [:string, {:list, :string}]},
      required: true,
      doc: "Text or list of texts to generate embeddings for."
    ]
  )

  schema(:upload_file_opts,
    purpose: [
      type: {:in, ["ocr", "fine-tune", "batch"]},
      required: true,
      doc: "The purpose of the file. Currently supports 'ocr', 'fine-tune', and 'batch'."
    ]
  )

  schema(:get_file_url_opts,
    expiry: [
      type: :integer,
      default: 24,
      doc: "Number of hours before the signed URL expires. Defaults to 24 hours."
    ]
  )

  schema(:document_url_chunk,
    type: [
      type: {:in, ["document_url"]},
      required: true,
      default: "document_url",
      doc: "Type of document, must be 'document_url'."
    ],
    document_url: [
      type: :string,
      required: true,
      doc: "URL of the document to be processed."
    ],
    document_name: [
      type: {:or, [:string, nil]},
      doc: "Optional filename of the document."
    ]
  )

  schema(:image_url_chunk,
    type: [
      type: :string,
      required: true,
      default: "image_url",
      doc: "Type of image, must be 'image_url'."
    ],
    image_url: [
      type: :string,
      required: true,
      doc: "URL of the image to be processed."
    ]
  )

  schema(:ocr_opts,
    model: [
      type: {:or, [:string, nil]},
      required: true,
      doc: "Model to use for OCR processing."
    ],
    id: [
      type: :string,
      doc: "Unique identifier for the OCR request."
    ],
    document: [
      type:
        {:or,
         [
           {:map, nested_schema(:document_url_chunk)},
           {:map, nested_schema(:image_url_chunk)}
         ]},
      required: true,
      doc: "Document object containing the URL or image URL."
    ],
    pages: [
      type: {:or, [nil, {:list, :integer}]},
      doc: "List of page indices to process (starting from 0)."
    ],
    include_image_base64: [
      type: {:or, [:boolean, nil]},
      doc: "Include base64 images in the response."
    ],
    image_limit: [
      type: {:or, [:integer, nil]},
      doc: "Maximum number of images to extract."
    ],
    image_min_size: [
      type: {:or, [:integer, nil]},
      doc: "Minimum image dimensions to extract."
    ]
  )

  @doc """
  Creates a new Mistral API client using the API key set in your application's config.

  ```elixir
  config :mistral, :api_key, "your-api-key"
  ```

  If given, a keyword list of options will be passed to `Req.new/1`.

  ## Examples

      iex> client = Mistral.init()
      %Mistral{}

      iex> client = Mistral.init(headers: [{"X-Custom-Header", "value"}])
      %Mistral{}
  """
  @spec init() :: client()
  def init, do: init([])

  @spec init(keyword()) :: client()
  def init(opts) when is_list(opts) do
    api_key = Application.fetch_env!(:mistral, :api_key)
    init(api_key, opts)
  end

  @doc """
  Creates a new Mistral API client with the given API key.

  Optionally, a keyword list of options can be passed through to `Req.new/1`.

  ## Examples

      iex> client = Mistral.init("YOUR_API_KEY")
      %Mistral{}

      iex> client = Mistral.init("YOUR_API_KEY", receive_timeout: :infinity)
      %Mistral{}
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

  #{doc(:chat)}

  ## Message structure

  Each message is a map with the following fields:

  #{doc(:chat_message)}

  ## Tool structure

  Each tool is a map with the following fields:

  #{doc(:tool_def)}

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
    with {:ok, params} <- NimbleOptions.validate(params, schema(:chat)) do
      {stream_opt, params} = Keyword.pop(params, :stream, false)

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

  @doc """
  Generate embeddings for the given input using a specified model.

  ## Options

  #{doc(:embed)}

  ## Examples

      iex> Mistral.embed(client, input: "Hello, world!")
      {:ok, %{"data" => [%{"embedding" => [...]}]}}

      iex> Mistral.embed(client, input: ["First text", "Second text"])
      {:ok, %{"data" => [%{"embedding" => [...]}, %{"embedding" => [...]}]}}
  """
  @spec embed(client(), keyword()) :: response()
  def embed(%__MODULE__{} = client, params) when is_list(params) do
    with {:ok, params} <- NimbleOptions.validate(params, schema(:embed)) do
      client
      |> req(:post, "/embeddings", json: Enum.into(params, %{}))
      |> res()
    end
  end

  @doc """
  Uploads a file to the Mistral API.

  ## Options

  #{doc(:upload_file_opts)}

  ## Examples

      iex> Mistral.upload_file(client, "path/to/file.pdf", purpose: "ocr")
      {:ok, %{"id" => "file-abc123", "object" => "file", ...}}
  """
  @spec upload_file(client(), Path.t(), keyword()) :: response()
  def upload_file(%__MODULE__{} = client, file_path, opts)
      when is_binary(file_path) and is_list(opts) do
    with {:ok, opts} <- NimbleOptions.validate(opts, schema(:upload_file_opts)),
         {:ok, file_binary} <- read_file(file_path) do
      filename = Path.basename(file_path)

      form_data = [
        purpose: Keyword.get(opts, :purpose),
        file: {file_binary, filename: filename}
      ]

      client
      |> req(:post, "/files", form_multipart: form_data)
      |> res()
    end
  end

  @doc """
  Retrieves information about a specific file by its ID.

  ## Parameters

    - `client`: A `Mistral.client()` struct.
    - `file_id`: The ID of the file to retrieve.

  ## Examples

      iex> Mistral.get_file(client, "00edaf84-95b0-45db-8f83-f71138491f23")
      {:ok, %{
        "id" => "00edaf84-95b0-45db-8f83-f71138491f23",
        "object" => "file",
        "bytes" => 3749788,
        "created_at" => 1741023462,
        "filename" => "test_document.pdf",
        "purpose" => "ocr",
        "sample_type" => "ocr_input",
        "source" => "upload",
        "deleted" => false
      }}
  """
  @spec get_file(client(), String.t()) :: response()
  def get_file(%__MODULE__{} = client, file_id) when is_binary(file_id) do
    client
    |> req(:get, "/files/#{file_id}")
    |> res()
  end

  @doc """
  Retrieves a signed URL for the specified file.

  ## Parameters

    - `client`: A `Mistral.client()` struct.
    - `file_id`: The ID of the file.
    - `opts`: An optional keyword list for additional query parameters (e.g., `expiry`).

  ## Examples

      iex> Mistral.get_file_url(client, "00edaf84-95b0-45db-8f83-f71138491f23")
      {:ok, %{"url" => "https://storage.googleapis.com/mistral-file-uploads/signed-url-example"}}

      iex> Mistral.get_file_url(client, "00edaf84-95b0-45db-8f83-f71138491f23", expiry: 48)
      {:ok, %{"url" => "https://storage.googleapis.com/mistral-file-uploads/signed-url-example"}}
  """
  @spec get_file_url(client(), String.t(), keyword()) :: response()
  def get_file_url(%__MODULE__{} = client, file_id, opts \\ [])
      when is_binary(file_id) and is_list(opts) do
    with {:ok, opts} <- NimbleOptions.validate(opts, schema(:get_file_url_opts)) do
      client
      |> req(:get, "/files/#{file_id}/url", params: opts)
      |> res()
    end
  end

  defp read_file(file_path) do
    case File.read(file_path) do
      {:ok, data} ->
        {:ok, data}

      {:error, reason} when is_atom(reason) ->
        {:error, %File.Error{reason: reason, action: "read file", path: file_path}}
    end
  end

  @doc """
  Perform OCR on a document or image.

  ## Options

  #{doc(:ocr_opts)}

  ## Examples

      iex> Mistral.ocr(client, model: "mistral-ocr-latest", document: %{type: "document_url", document_url: "https://example.com/sample.pdf"})
      {:ok, %{"pages" => [...]}}

      iex> Mistral.ocr(client, model: "mistral-ocr-latest", document: %{type: "image_url", image_url: "https://example.com/sample.png"})
      {:ok, %{"pages" => [...]}}

  """
  @spec ocr(client(), keyword()) :: response()
  def ocr(%__MODULE__{} = client, params) when is_list(params) do
    with {:ok, params} <- NimbleOptions.validate(params, schema(:ocr_opts)) do
      client
      |> req(:post, "/ocr", json: Enum.into(params, %{}))
      |> res()
    end
  end

  @doc """
  Lists all available models.

  ## Examples

      iex> Mistral.list_models(client)
      {:ok, %{
        "object" => "list",
        "data" => [
          %{
            "id" => "mistral-small-latest",
            "object" => "model",
            "created" => 1711430400,
            "owned_by" => "mistralai",
            "capabilities" => %{
              "completion_chat" => true,
              "function_calling" => true
            }
          }
        ]
      }}
  """
  @spec list_models(client()) :: response()
  def list_models(%__MODULE__{} = client) do
    client
    |> req(:get, "/models")
    |> res()
  end

  @doc """
  Retrieves information about a specific model by its ID.

  ## Parameters

    - `client`: A `Mistral.client()` struct.
    - `model_id`: The ID of the model to retrieve (e.g. "mistral-small-latest").

  ## Examples

      iex> Mistral.get_model(client, "mistral-small-latest")
      {:ok, %{
        "id" => "mistral-small-latest",
        "object" => "model",
        "created" => 1711430400,
        "owned_by" => "mistralai",
        "capabilities" => %{
          "completion_chat" => true,
          "function_calling" => true,
          "vision" => false
        },
        "name" => "Mistral Small"
      }}
  """
  @spec get_model(client(), String.t()) :: response()
  def get_model(%__MODULE__{} = client, model_id) when is_binary(model_id) do
    client
    |> req(:get, "/models/#{model_id}")
    |> res()
  end

  @spec req(client(), atom(), Req.url(), keyword()) :: req_response()
  def req(%__MODULE__{req: req}, method, url, opts \\ []) do
    opts = Keyword.merge(opts, method: method, url: url)
    Req.request(req, opts)
  end

  @spec res(req_response()) :: response()
  def res({:ok, %Task{} = task}), do: {:ok, task}
  def res({:ok, stream}) when is_function(stream), do: {:ok, stream}

  def res({:ok, %Req.Response{status: status, body: ""}}) when status in 200..299,
    do: {:ok, %{}}

  def res({:ok, %Req.Response{status: status, body: body}}) when status in 200..299,
    do: {:ok, body}

  def res({:ok, resp}),
    do: {:error, APIError.exception(resp)}

  def res({:error, error}), do: {:error, error}
end
