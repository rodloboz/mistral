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
          {:ok, map() | binary() | Enumerable.t() | Task.t()}
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

  schema(:chat_classification_input,
    messages: [
      type: {:list, {:map, nested_schema(:chat_message)}},
      required: true,
      doc: "List of messages in the conversation."
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

  schema(:json_schema,
    name: [
      type: :string,
      required: true,
      doc: "The name of the JSON schema."
    ],
    schema: [
      type: @permissive_map,
      required: true,
      doc: "The JSON Schema object defining the structure."
    ],
    strict: [
      type: :boolean,
      default: true,
      doc: "Whether to enforce strict schema validation."
    ]
  )

  schema(:response_format,
    type: [
      type: {:in, ["text", "json_object", "json_schema"]},
      default: "text",
      doc:
        "The format type. 'text' for normal text, 'json_object' for JSON mode, 'json_schema' for structured output."
    ],
    json_schema: [
      type: {:or, [{:map, nested_schema(:json_schema)}, nil]},
      doc: "*(required when type is 'json_schema')* The JSON schema definition."
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
    ],
    response_format: [
      type: {:or, [{:map, nested_schema(:response_format)}, nil]},
      doc:
        "*(optional)* Controls the output format. Use for JSON mode or structured output with schema validation."
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

  schema(:text_classification,
    model: [type: :string, required: true, doc: "ID of the model to use."],
    input: [
      type: {:or, [:string, {:list, :string}]},
      required: true,
      doc: "Text or list of texts to classify."
    ]
  )

  schema(:chat_classification,
    model: [type: :string, required: true, doc: "ID of the model to use."],
    input: [
      type:
        {:or,
         [
           {:map, nested_schema(:chat_classification_input)},
           {:list, {:map, nested_schema(:chat_classification_input)}}
         ]},
      required: true,
      doc: "A single conversation or list of conversations to classify."
    ]
  )

  schema(:chat_moderation,
    model: [type: :string, required: true, doc: "ID of the model to use."],
    input: [
      type:
        {:or,
         [
           {:list, {:map, nested_schema(:chat_message)}},
           {:list, {:list, {:map, nested_schema(:chat_message)}}}
         ]},
      required: true,
      doc:
        "A single conversation (list of messages) or multiple conversations (list of lists of messages) to moderate."
    ]
  )

  schema(:batch_request,
    custom_id: [type: :string, doc: "*(optional)* Custom identifier for this request."],
    body: [
      type: @permissive_map,
      required: true,
      doc: "The request body for the batch inference."
    ]
  )

  schema(:create_batch_job,
    input_files: [
      type: {:list, :string},
      doc: "*(optional)* List of file IDs (UUIDs) to use as input. Files must be JSONL format."
    ],
    requests: [
      type: {:list, {:map, nested_schema(:batch_request)}},
      doc: "*(optional)* Inline list of batch requests (max 10,000)."
    ],
    endpoint: [
      type:
        {:in,
         [
           "/v1/chat/completions",
           "/v1/embeddings",
           "/v1/fim/completions",
           "/v1/moderations",
           "/v1/chat/moderations",
           "/v1/ocr",
           "/v1/classifications",
           "/v1/chat/classifications"
         ]},
      required: true,
      doc: "The API endpoint to use for batch inference."
    ],
    model: [type: :string, doc: "*(optional)* The model to use for batch inference."],
    metadata: [
      type: @permissive_map,
      doc: "*(optional)* Metadata to associate with the batch job."
    ],
    timeout_hours: [type: :integer, default: 24, doc: "Timeout in hours for the batch job."]
  )

  schema(:list_batch_jobs,
    page: [type: :integer, doc: "*(optional)* Page number (0-indexed)."],
    page_size: [type: :integer, doc: "*(optional)* Number of items per page."],
    model: [type: :string, doc: "*(optional)* Filter by model."],
    created_after: [
      type: :string,
      doc: "*(optional)* Filter jobs created after this datetime (ISO 8601)."
    ],
    created_by_me: [
      type: :boolean,
      default: false,
      doc: "*(optional)* Only return jobs created by the current user."
    ],
    status: [
      type:
        {:list,
         {:in,
          [
            "QUEUED",
            "RUNNING",
            "SUCCESS",
            "FAILED",
            "TIMEOUT_EXCEEDED",
            "CANCELLATION_REQUESTED",
            "CANCELLED"
          ]}},
      doc: "*(optional)* Filter by job status."
    ]
  )

  schema(:get_batch_job_opts,
    inline: [type: :boolean, doc: "*(optional)* If true, return results inline in the response."]
  )

  schema(:training_file,
    file_id: [type: :string, required: true, doc: "The ID (UUID) of an uploaded training file."],
    weight: [type: :float, default: 1.0, doc: "*(optional)* Weight of the training file."]
  )

  schema(:wandb_integration,
    type: [type: {:in, ["wandb"]}, default: "wandb", doc: "Integration type."],
    project: [type: :string, required: true, doc: "The W&B project name."],
    name: [type: :string, doc: "*(optional)* Display name for the run."],
    api_key: [type: :string, required: true, doc: "The W&B API key (40 characters)."],
    run_name: [type: :string, doc: "*(optional)* The W&B run name."]
  )

  schema(:github_repository,
    type: [type: {:in, ["github"]}, default: "github", doc: "Repository type."],
    name: [type: :string, required: true, doc: "The repository name."],
    owner: [type: :string, required: true, doc: "The repository owner."],
    ref: [type: :string, doc: "*(optional)* Git ref (branch, tag, or commit)."],
    weight: [type: :float, default: 1.0, doc: "*(optional)* Weight of this repository."],
    token: [type: :string, required: true, doc: "GitHub access token."]
  )

  schema(:classifier_target,
    name: [type: :string, required: true, doc: "Target name."],
    labels: [type: {:list, :string}, required: true, doc: "List of labels."],
    weight: [type: :float, default: 1.0, doc: "*(optional)* Target weight."],
    loss_function: [
      type: {:in, ["single_class", "multi_class"]},
      doc: "*(optional)* Loss function."
    ]
  )

  schema(:create_fine_tuning_job,
    model: [
      type:
        {:in,
         [
           "open-mistral-7b",
           "mistral-small-latest",
           "codestral-latest",
           "mistral-large-latest",
           "open-mistral-nemo",
           "codestral-mamba-latest"
         ]},
      required: true,
      doc: "The model to fine-tune."
    ],
    training_files: [
      type: {:list, {:map, nested_schema(:training_file)}},
      doc: "*(optional)* List of training file objects."
    ],
    validation_files: [
      type: {:list, :string},
      doc: "*(optional)* List of validation file IDs (UUIDs)."
    ],
    suffix: [
      type: :string,
      doc: "*(optional)* A suffix to append to the fine-tuned model name."
    ],
    integrations: [
      type: {:list, {:map, nested_schema(:wandb_integration)}},
      doc: "*(optional)* List of W&B integrations."
    ],
    auto_start: [
      type: :boolean,
      doc: "*(optional)* Whether to start the job automatically after validation."
    ],
    hyperparameters: [
      type: @permissive_map,
      required: true,
      doc: "Hyperparameters for fine-tuning (e.g. training_steps, learning_rate, etc.)."
    ],
    repositories: [
      type: {:list, {:map, nested_schema(:github_repository)}},
      doc: "*(optional)* List of GitHub repositories to use as training data."
    ],
    classifier_targets: [
      type: {:list, {:map, nested_schema(:classifier_target)}},
      doc: "*(optional)* List of classifier targets (for classifier job type)."
    ],
    job_type: [
      type: {:in, ["completion", "classifier"]},
      doc: "*(optional)* The type of fine-tuning job."
    ],
    invalid_sample_skip_percentage: [
      type: :float,
      default: 0.0,
      doc: "*(optional)* Percentage of invalid samples to skip during training."
    ],
    dry_run: [
      type: :boolean,
      doc: "*(optional)* If true, returns estimated cost and duration without creating the job."
    ]
  )

  schema(:list_fine_tuning_jobs,
    page: [type: :integer, doc: "*(optional)* Page number (0-indexed)."],
    page_size: [type: :integer, doc: "*(optional)* Number of items per page."],
    model: [type: :string, doc: "*(optional)* Filter by model."],
    created_after: [
      type: :string,
      doc: "*(optional)* Filter jobs created after this datetime (ISO 8601)."
    ],
    created_before: [
      type: :string,
      doc: "*(optional)* Filter jobs created before this datetime (ISO 8601)."
    ],
    wandb_project: [type: :string, doc: "*(optional)* Filter by W&B project name."],
    wandb_name: [type: :string, doc: "*(optional)* Filter by W&B run name."],
    suffix: [type: :string, doc: "*(optional)* Filter by model suffix."],
    created_by_me: [
      type: :boolean,
      default: false,
      doc: "*(optional)* Only return jobs created by the current user."
    ],
    status: [
      type:
        {:in,
         [
           "QUEUED",
           "STARTED",
           "VALIDATING",
           "VALIDATED",
           "RUNNING",
           "FAILED_VALIDATION",
           "FAILED",
           "SUCCESS",
           "CANCELLED",
           "CANCELLATION_REQUESTED"
         ]},
      doc: "*(optional)* Filter by job status."
    ]
  )

  schema(:update_fine_tuned_model,
    name: [type: :string, doc: "*(optional)* New name for the fine-tuned model."],
    description: [type: :string, doc: "*(optional)* New description for the fine-tuned model."]
  )

  schema(:fim,
    model: [
      type: :string,
      required: true,
      doc: "ID of the model to use for FIM completion (e.g. `codestral-latest`)."
    ],
    prompt: [
      type: :string,
      required: true,
      doc: "The text/code to complete."
    ],
    suffix: [
      type: :string,
      doc:
        "*(optional)* Text/code that adds more context. When given a `prompt` and a `suffix`, the model fills what is between them."
    ],
    temperature: [
      type: :float,
      doc: "Controls randomness (0.0 to 1.5)."
    ],
    top_p: [
      type: :float,
      default: 1.0,
      doc: "Controls diversity via nucleus sampling."
    ],
    max_tokens: [
      type: :non_neg_integer,
      doc: "Maximum number of tokens to generate."
    ],
    min_tokens: [
      type: :non_neg_integer,
      doc: "Minimum number of tokens to generate."
    ],
    stream: [
      type: {:or, [:boolean, :pid]},
      default: false,
      doc: "When true, returns a stream of partial response chunks."
    ],
    stop: [
      type: {:or, [:string, {:list, :string}]},
      doc: "Stop generation if this token is detected."
    ],
    random_seed: [
      type: :non_neg_integer,
      doc: "Seed for deterministic results."
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

  schema(:list_files_opts,
    page: [
      type: :integer,
      doc: "*(optional)* Pagination page number."
    ],
    page_size: [
      type: :integer,
      doc: "*(optional)* Number of items per page."
    ],
    sample_type: [
      type: {:list, :string},
      doc: "*(optional)* Filter by sample type."
    ],
    source: [
      type: {:list, :string},
      doc: "*(optional)* Filter by source."
    ],
    search: [
      type: :string,
      doc: "*(optional)* Search query."
    ],
    purpose: [
      type: {:in, ["ocr", "fine-tune", "batch"]},
      doc: "*(optional)* Filter by purpose. Supports 'ocr', 'fine-tune', and 'batch'."
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
    ],
    bbox_annotation_format: [
      type: {:or, [{:map, nested_schema(:response_format)}, nil]},
      doc:
        "*(optional)* Structured output for extracting information from each bounding box/image. Only json_schema type is valid."
    ],
    document_annotation_format: [
      type: {:or, [{:map, nested_schema(:response_format)}, nil]},
      doc:
        "*(optional)* Structured output for extracting information from the entire document. Only json_schema type is valid."
    ]
  )

  schema(:agent_tool,
    type: [
      type:
        {:in,
         [
           "function",
           "web_search",
           "web_search_premium",
           "code_interpreter",
           "image_generation",
           "document_library"
         ]},
      required: true,
      doc: "The type of tool."
    ],
    function: [
      type: :map,
      keys: nested_schema(:function_def),
      doc: "*(required when type is 'function')* The function definition."
    ],
    library_ids: [
      type: {:list, :string},
      doc: "*(required when type is 'document_library')* IDs of the libraries to search."
    ]
  )

  schema(:completion_args,
    stop: [type: {:or, [:string, {:list, :string}]}, doc: "Stop token(s)."],
    presence_penalty: [type: :float, doc: "Presence penalty (-2 to 2)."],
    frequency_penalty: [type: :float, doc: "Frequency penalty (-2 to 2)."],
    temperature: [type: :float, doc: "Temperature (0 to 1)."],
    top_p: [type: :float, doc: "Top-p sampling (0 to 1)."],
    max_tokens: [type: :non_neg_integer, doc: "Maximum tokens."],
    random_seed: [type: :non_neg_integer, doc: "Random seed."],
    response_format: [
      type: {:or, [{:map, nested_schema(:response_format)}, nil]},
      doc: "Response format."
    ],
    tool_choice: [
      type: {:in, ["auto", "none", "any", "required"]},
      default: "auto",
      doc: "Tool choice strategy."
    ]
  )

  schema(:create_agent,
    model: [type: :string, required: true, doc: "Model ID to use."],
    name: [type: :string, required: true, doc: "Agent name."],
    instructions: [type: {:or, [:string, nil]}, doc: "System instructions."],
    tools: [
      type: {:list, {:map, nested_schema(:agent_tool)}},
      doc: "Available tools."
    ],
    completion_args: [
      type: :map,
      keys: nested_schema(:completion_args),
      doc: "Default completion arguments."
    ],
    description: [type: {:or, [:string, nil]}, doc: "Agent description."],
    handoffs: [type: {:list, :string}, doc: "Agent IDs for handoff."],
    metadata: [type: @permissive_map, doc: "Custom metadata."]
  )

  schema(:update_agent,
    model: [type: {:or, [:string, nil]}, doc: "Model ID."],
    name: [type: {:or, [:string, nil]}, doc: "Agent name."],
    instructions: [type: {:or, [:string, nil]}, doc: "System instructions."],
    tools: [
      type: {:list, {:map, nested_schema(:agent_tool)}},
      doc: "Available tools."
    ],
    completion_args: [
      type: :map,
      keys: nested_schema(:completion_args),
      doc: "Default completion arguments."
    ],
    description: [type: {:or, [:string, nil]}, doc: "Agent description."],
    handoffs: [type: {:or, [{:list, :string}, nil]}, doc: "Agent IDs for handoff."],
    deployment_chat: [type: {:or, [:boolean, nil]}, doc: "Deployment chat flag."],
    metadata: [type: @permissive_map, doc: "Custom metadata."]
  )

  schema(:list_agents,
    page: [type: :integer, doc: "Page number (0-indexed)."],
    page_size: [type: :integer, doc: "Items per page (1-1000)."],
    deployment_chat: [type: :boolean, doc: "Filter by deployment chat."],
    sources: [
      type: {:list, {:in, ["api", "playground", "agent_builder_v1"]}},
      doc: "Filter by sources."
    ],
    name: [type: :string, doc: "Filter by name."],
    id: [type: :string, doc: "Filter by ID."]
  )

  schema(:get_agent_opts,
    agent_version: [
      type: {:or, [:integer, :string]},
      doc: "Version number or alias."
    ]
  )

  schema(:list_agent_versions,
    page: [type: :integer, doc: "Page number (0-indexed)."],
    page_size: [type: :integer, doc: "Versions per page (1-100)."]
  )

  schema(:agent_completion,
    agent_id: [type: :string, required: true, doc: "ID of the agent."],
    messages: [
      type: {:list, {:map, nested_schema(:chat_message)}},
      required: true,
      doc: "Messages."
    ],
    max_tokens: [type: :non_neg_integer, doc: "Maximum tokens."],
    stream: [type: {:or, [:boolean, :pid]}, default: false, doc: "Stream response."],
    stop: [type: {:or, [:string, {:list, :string}]}, doc: "Stop token(s)."],
    random_seed: [type: :non_neg_integer, doc: "Random seed."],
    response_format: [
      type: {:or, [{:map, nested_schema(:response_format)}, nil]},
      doc: "Response format."
    ],
    tools: [
      type: {:list, {:map, nested_schema(:tool_def)}},
      doc: "Available tools."
    ],
    tool_choice: [type: {:or, [:string, @permissive_map]}, doc: "Tool choice."],
    presence_penalty: [type: :float, default: 0.0, doc: "Presence penalty."],
    frequency_penalty: [type: :float, default: 0.0, doc: "Frequency penalty."],
    n: [type: :pos_integer, doc: "Number of completions."],
    metadata: [type: @permissive_map, doc: "Custom metadata."]
  )

  schema(:create_conversation,
    inputs: [
      type: {:or, [:string, {:list, @permissive_map}]},
      required: true,
      doc: "The input string or list of entry objects."
    ],
    stream: [
      type: {:or, [:boolean, :pid]},
      default: false,
      doc: "When true, returns a stream of response events."
    ],
    store: [
      type: {:or, [:boolean, nil]},
      doc: "*(optional)* Whether to store the conversation."
    ],
    handoff_execution: [
      type: {:or, [{:in, ["client", "server"]}, nil]},
      doc: "*(optional)* Handoff execution mode ('client' or 'server')."
    ],
    instructions: [
      type: {:or, [:string, nil]},
      doc: "*(optional)* System instructions for the conversation."
    ],
    tools: [
      type: {:list, @permissive_map},
      doc: "*(optional)* Available tools (function, web_search, code_interpreter, etc.)."
    ],
    completion_args: [
      type: {:or, [{:map, nested_schema(:completion_args)}, nil]},
      doc: "*(optional)* Completion arguments."
    ],
    name: [
      type: {:or, [:string, nil]},
      doc: "*(optional)* Name of the conversation."
    ],
    description: [
      type: {:or, [:string, nil]},
      doc: "*(optional)* Description of the conversation."
    ],
    metadata: [
      type: {:or, [@permissive_map, nil]},
      doc: "*(optional)* Custom metadata."
    ],
    agent_id: [
      type: {:or, [:string, nil]},
      doc: "*(optional)* Agent ID to use."
    ],
    agent_version: [
      type: {:or, [:string, :integer, nil]},
      doc: "*(optional)* Agent version."
    ],
    model: [
      type: {:or, [:string, nil]},
      doc: "*(optional)* Model ID to use."
    ]
  )

  schema(:append_conversation,
    inputs: [
      type: {:or, [:string, {:list, @permissive_map}]},
      required: true,
      doc: "The input string or list of entry objects."
    ],
    stream: [
      type: {:or, [:boolean, :pid]},
      default: false,
      doc: "When true, returns a stream of response events."
    ],
    store: [
      type: :boolean,
      default: true,
      doc: "Whether to store the entries."
    ],
    handoff_execution: [
      type: {:in, ["client", "server"]},
      default: "server",
      doc: "Handoff execution mode."
    ],
    completion_args: [
      type: {:or, [{:map, nested_schema(:completion_args)}, nil]},
      doc: "*(optional)* Completion arguments."
    ]
  )

  schema(:restart_conversation,
    inputs: [
      type: {:or, [:string, {:list, @permissive_map}]},
      required: true,
      doc: "The input string or list of entry objects."
    ],
    from_entry_id: [
      type: :string,
      required: true,
      doc: "The entry ID to restart from."
    ],
    stream: [
      type: {:or, [:boolean, :pid]},
      default: false,
      doc: "When true, returns a stream of response events."
    ],
    store: [
      type: :boolean,
      default: true,
      doc: "Whether to store the entries."
    ],
    handoff_execution: [
      type: {:in, ["client", "server"]},
      default: "server",
      doc: "Handoff execution mode."
    ],
    completion_args: [
      type: {:or, [{:map, nested_schema(:completion_args)}, nil]},
      doc: "*(optional)* Completion arguments."
    ]
  )

  schema(:list_conversations_opts,
    page: [type: :integer, doc: "*(optional)* Page number."],
    page_size: [type: :integer, doc: "*(optional)* Items per page."]
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

      ## Response Format Control

      You can control the output format using the `response_format` parameter:

      iex> # JSON mode - ensures response is valid JSON
      iex> Mistral.chat(client, [
      ...>   model: "mistral-small-latest",
      ...>   messages: [%{role: "user", content: "Generate user data in JSON format"}],
      ...>   response_format: %{type: "json_object"}
      ...> ])

      iex> # JSON Schema mode - validates response against schema
      iex> user_schema = %{
      ...>   type: "object",
      ...>   title: "UserProfile",
      ...>   properties: %{
      ...>     name: %{type: "string", title: "Name"},
      ...>     age: %{type: "integer", title: "Age", minimum: 0},
      ...>     email: %{type: "string", title: "Email"}
      ...>   },
      ...>   required: ["name", "age"],
      ...>   additionalProperties: false
      ...> }
      iex> Mistral.chat(client, [
      ...>   model: "mistral-small-latest",
      ...>   messages: [%{role: "user", content: "Generate a user profile"}],
      ...>   response_format: %{
      ...>     type: "json_schema",
      ...>     json_schema: %{
      ...>       name: "user_profile",
      ...>       schema: user_schema,
      ...>       strict: true
      ...>     }
      ...>   }
      ...> ])
  """
  @spec chat(client(), keyword()) :: response()
  def chat(%__MODULE__{} = client, params) when is_list(params) do
    with {:ok, params} <- NimbleOptions.validate(params, schema(:chat)),
         :ok <- validate_response_format(params) do
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
  Fill-in-the-middle completion for code. Given a code `prompt` (and optional `suffix`),
  the model generates the code that fits between them.

  ## Options

  #{doc(:fim)}

  ## Examples

      iex> Mistral.fim(client, model: "codestral-latest", prompt: "def add(a, b):\\n    ")
      {:ok, %{"choices" => [%{"message" => %{"content" => "return a + b"}}], ...}}

      # With suffix for fill-in-the-middle
      iex> Mistral.fim(client, model: "codestral-latest", prompt: "def ", suffix: "return a + b")
      {:ok, %{"choices" => [%{"message" => %{"content" => "add(a, b):\\n    "}}], ...}}

      # Stream the response
      iex> {:ok, stream} = Mistral.fim(client, model: "codestral-latest", prompt: "def ", stream: true)
      iex> Enum.to_list(stream)
      [%{"choices" => [%{"delta" => ...}]}, ...]
  """
  @spec fim(client(), keyword()) :: response()
  def fim(%__MODULE__{} = client, params) when is_list(params) do
    with {:ok, params} <- NimbleOptions.validate(params, schema(:fim)) do
      {stream_opt, params} = Keyword.pop(params, :stream, false)

      if stream_opt do
        params = Keyword.put(params, :stream, true)
        dest = if is_pid(stream_opt), do: stream_opt, else: self()

        task =
          Task.async(fn ->
            client
            |> req(:post, "/fim/completions",
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
        |> req(:post, "/fim/completions", json: Enum.into(params, %{}))
        |> res()
      end
    end
  end

  @doc """
  Classify text using a Mistral moderation model.

  ## Options

  #{doc(:text_classification)}

  ## Examples

      iex> Mistral.classify(client, model: "mistral-moderation-latest", input: "Hello, world!")
      {:ok, %{"id" => "...", "model" => "mistral-moderation-latest", "results" => [...]}}

      iex> Mistral.classify(client, model: "mistral-moderation-latest", input: ["First text", "Second text"])
      {:ok, %{"id" => "...", "model" => "mistral-moderation-latest", "results" => [...]}}
  """
  @spec classify(client(), keyword()) :: response()
  def classify(%__MODULE__{} = client, params) when is_list(params) do
    with {:ok, params} <- NimbleOptions.validate(params, schema(:text_classification)) do
      client
      |> req(:post, "/classifications", json: Enum.into(params, %{}))
      |> res()
    end
  end

  @doc """
  Classify chat conversations using a Mistral moderation model.

  ## Options

  #{doc(:chat_classification)}

  ## Examples

      iex> Mistral.classify_chat(client,
      ...>   model: "mistral-moderation-latest",
      ...>   input: %{messages: [%{role: "user", content: "Hello"}]}
      ...> )
      {:ok, %{"id" => "...", "model" => "mistral-moderation-latest", "results" => [...]}}
  """
  @spec classify_chat(client(), keyword()) :: response()
  def classify_chat(%__MODULE__{} = client, params) when is_list(params) do
    with {:ok, params} <- NimbleOptions.validate(params, schema(:chat_classification)) do
      client
      |> req(:post, "/chat/classifications", json: Enum.into(params, %{}))
      |> res()
    end
  end

  @doc """
  Moderate text using a Mistral moderation model.

  ## Options

  #{doc(:text_classification)}

  ## Examples

      iex> Mistral.moderate(client, model: "mistral-moderation-latest", input: "Hello, world!")
      {:ok, %{"id" => "...", "model" => "mistral-moderation-latest", "results" => [...]}}

      iex> Mistral.moderate(client, model: "mistral-moderation-latest", input: ["First text", "Second text"])
      {:ok, %{"id" => "...", "model" => "mistral-moderation-latest", "results" => [...]}}
  """
  @spec moderate(client(), keyword()) :: response()
  def moderate(%__MODULE__{} = client, params) when is_list(params) do
    with {:ok, params} <- NimbleOptions.validate(params, schema(:text_classification)) do
      client
      |> req(:post, "/moderations", json: Enum.into(params, %{}))
      |> res()
    end
  end

  @doc """
  Moderate chat conversations using a Mistral moderation model.

  ## Options

  #{doc(:chat_moderation)}

  ## Examples

      iex> Mistral.moderate_chat(client,
      ...>   model: "mistral-moderation-latest",
      ...>   input: [%{role: "user", content: "Hello"}]
      ...> )
      {:ok, %{"id" => "...", "model" => "mistral-moderation-latest", "results" => [...]}}
  """
  @spec moderate_chat(client(), keyword()) :: response()
  def moderate_chat(%__MODULE__{} = client, params) when is_list(params) do
    with {:ok, params} <- NimbleOptions.validate(params, schema(:chat_moderation)) do
      client
      |> req(:post, "/chat/moderations", json: Enum.into(params, %{}))
      |> res()
    end
  end

  @doc """
  Create a batch job for asynchronous batch inference.

  Provide either `input_files` (list of uploaded JSONL file IDs) or `requests`
  (inline list of batch request objects). The `endpoint` parameter specifies which
  API endpoint to use for processing.

  ## Options

  #{doc(:create_batch_job)}

  ## Batch request structure

  #{doc(:batch_request)}

  ## Examples

      iex> Mistral.create_batch_job(client,
      ...>   endpoint: "/v1/chat/completions",
      ...>   input_files: ["file-abc123"]
      ...> )
      {:ok, %{"id" => "b_abc123", "status" => "QUEUED", ...}}

      iex> Mistral.create_batch_job(client,
      ...>   endpoint: "/v1/chat/completions",
      ...>   model: "mistral-small-latest",
      ...>   requests: [
      ...>     %{custom_id: "req-1", body: %{messages: [%{role: "user", content: "Hello"}]}}
      ...>   ]
      ...> )
      {:ok, %{"id" => "b_abc123", "status" => "QUEUED", ...}}
  """
  @spec create_batch_job(client(), keyword()) :: response()
  def create_batch_job(%__MODULE__{} = client, params) when is_list(params) do
    with {:ok, params} <- NimbleOptions.validate(params, schema(:create_batch_job)) do
      client
      |> req(:post, "/batch/jobs", json: Enum.into(params, %{}))
      |> res()
    end
  end

  @doc """
  List batch jobs with optional filtering and pagination.

  ## Options

  #{doc(:list_batch_jobs)}

  ## Examples

      iex> Mistral.list_batch_jobs(client)
      {:ok, %{"object" => "list", "data" => [...], "total" => 2}}

      iex> Mistral.list_batch_jobs(client, status: ["QUEUED", "RUNNING"], model: "mistral-small-latest")
      {:ok, %{"object" => "list", "data" => [...], "total" => 1}}
  """
  @spec list_batch_jobs(client(), keyword()) :: response()
  def list_batch_jobs(%__MODULE__{} = client, opts \\ []) when is_list(opts) do
    with {:ok, opts} <- NimbleOptions.validate(opts, schema(:list_batch_jobs)) do
      client
      |> req(:get, "/batch/jobs", params: expand_list_params(opts))
      |> res()
    end
  end

  @doc """
  Retrieve a batch job by its ID.

  ## Options

  #{doc(:get_batch_job_opts)}

  ## Examples

      iex> Mistral.get_batch_job(client, "b_abc123")
      {:ok, %{"id" => "b_abc123", "status" => "QUEUED", ...}}

      iex> Mistral.get_batch_job(client, "b_abc123", inline: true)
      {:ok, %{"id" => "b_abc123", "status" => "SUCCESS", "results" => [...], ...}}
  """
  @spec get_batch_job(client(), String.t(), keyword()) :: response()
  def get_batch_job(%__MODULE__{} = client, job_id, opts \\ [])
      when is_binary(job_id) and is_list(opts) do
    with {:ok, opts} <- NimbleOptions.validate(opts, schema(:get_batch_job_opts)) do
      client
      |> req(:get, "/batch/jobs/#{job_id}", params: opts)
      |> res()
    end
  end

  @doc """
  Cancel a batch job by its ID.

  ## Examples

      iex> Mistral.cancel_batch_job(client, "b_abc123")
      {:ok, %{"id" => "b_abc123", "status" => "CANCELLATION_REQUESTED", ...}}
  """
  @spec cancel_batch_job(client(), String.t()) :: response()
  def cancel_batch_job(%__MODULE__{} = client, job_id) when is_binary(job_id) do
    client
    |> req(:post, "/batch/jobs/#{job_id}/cancel", json: %{})
    |> res()
  end

  @doc """
  Create a fine-tuning job.

  ## Options

  #{doc(:create_fine_tuning_job)}

  ## Training file structure

  #{doc(:training_file)}

  ## W&B integration structure

  #{doc(:wandb_integration)}

  ## Examples

      iex> Mistral.create_fine_tuning_job(client,
      ...>   model: "open-mistral-7b",
      ...>   hyperparameters: %{training_steps: 10},
      ...>   training_files: [%{file_id: "file-abc123"}]
      ...> )
      {:ok, %{"id" => "ft-abc123", "status" => "QUEUED", ...}}

      iex> Mistral.create_fine_tuning_job(client,
      ...>   model: "open-mistral-7b",
      ...>   hyperparameters: %{training_steps: 10},
      ...>   dry_run: true
      ...> )
      {:ok, %{"expected_duration_seconds" => 300, ...}}
  """
  @spec create_fine_tuning_job(client(), keyword()) :: response()
  def create_fine_tuning_job(%__MODULE__{} = client, params) when is_list(params) do
    with {:ok, params} <- NimbleOptions.validate(params, schema(:create_fine_tuning_job)) do
      {dry_run, params} = Keyword.pop(params, :dry_run)

      client
      |> req(:post, "/fine_tuning/jobs",
        json: Enum.into(params, %{}),
        params: if(dry_run != nil, do: [dry_run: dry_run], else: [])
      )
      |> res()
    end
  end

  @doc """
  List fine-tuning jobs with optional filtering and pagination.

  ## Options

  #{doc(:list_fine_tuning_jobs)}

  ## Examples

      iex> Mistral.list_fine_tuning_jobs(client)
      {:ok, %{"object" => "list", "data" => [...], "total" => 2}}

      iex> Mistral.list_fine_tuning_jobs(client, status: "RUNNING", model: "open-mistral-7b")
      {:ok, %{"object" => "list", "data" => [...], "total" => 1}}
  """
  @spec list_fine_tuning_jobs(client(), keyword()) :: response()
  def list_fine_tuning_jobs(%__MODULE__{} = client, opts \\ []) when is_list(opts) do
    with {:ok, opts} <- NimbleOptions.validate(opts, schema(:list_fine_tuning_jobs)) do
      client
      |> req(:get, "/fine_tuning/jobs", params: opts)
      |> res()
    end
  end

  @doc """
  Retrieve a fine-tuning job by its ID.

  ## Examples

      iex> Mistral.get_fine_tuning_job(client, "ft-abc123")
      {:ok, %{"id" => "ft-abc123", "status" => "QUEUED", ...}}
  """
  @spec get_fine_tuning_job(client(), String.t()) :: response()
  def get_fine_tuning_job(%__MODULE__{} = client, job_id) when is_binary(job_id) do
    client
    |> req(:get, "/fine_tuning/jobs/#{job_id}")
    |> res()
  end

  @doc """
  Cancel a fine-tuning job by its ID.

  ## Examples

      iex> Mistral.cancel_fine_tuning_job(client, "ft-abc123")
      {:ok, %{"id" => "ft-abc123", "status" => "CANCELLATION_REQUESTED", ...}}
  """
  @spec cancel_fine_tuning_job(client(), String.t()) :: response()
  def cancel_fine_tuning_job(%__MODULE__{} = client, job_id) when is_binary(job_id) do
    client
    |> req(:post, "/fine_tuning/jobs/#{job_id}/cancel", json: %{})
    |> res()
  end

  @doc """
  Start a fine-tuning job by its ID.

  ## Examples

      iex> Mistral.start_fine_tuning_job(client, "ft-abc123")
      {:ok, %{"id" => "ft-abc123", "status" => "STARTED", ...}}
  """
  @spec start_fine_tuning_job(client(), String.t()) :: response()
  def start_fine_tuning_job(%__MODULE__{} = client, job_id) when is_binary(job_id) do
    client
    |> req(:post, "/fine_tuning/jobs/#{job_id}/start", json: %{})
    |> res()
  end

  @doc """
  Update a fine-tuned model's name and/or description.

  ## Options

  #{doc(:update_fine_tuned_model)}

  ## Examples

      iex> Mistral.update_fine_tuned_model(client, "ft:open-mistral-7b:abc123",
      ...>   name: "My Model",
      ...>   description: "A fine-tuned model"
      ...> )
      {:ok, %{"id" => "ft:open-mistral-7b:abc123", ...}}
  """
  @spec update_fine_tuned_model(client(), String.t(), keyword()) :: response()
  def update_fine_tuned_model(%__MODULE__{} = client, model_id, params \\ [])
      when is_binary(model_id) and is_list(params) do
    with {:ok, params} <- NimbleOptions.validate(params, schema(:update_fine_tuned_model)) do
      client
      |> req(:patch, "/fine_tuning/models/#{model_id}", json: Enum.into(params, %{}))
      |> res()
    end
  end

  @doc """
  Archive a fine-tuned model.

  ## Examples

      iex> Mistral.archive_fine_tuned_model(client, "ft:open-mistral-7b:abc123")
      {:ok, %{"id" => "ft:open-mistral-7b:abc123", "archived" => true, ...}}
  """
  @spec archive_fine_tuned_model(client(), String.t()) :: response()
  def archive_fine_tuned_model(%__MODULE__{} = client, model_id) when is_binary(model_id) do
    client
    |> req(:post, "/fine_tuning/models/#{model_id}/archive", json: %{})
    |> res()
  end

  @doc """
  Unarchive a fine-tuned model.

  ## Examples

      iex> Mistral.unarchive_fine_tuned_model(client, "ft:open-mistral-7b:abc123")
      {:ok, %{"id" => "ft:open-mistral-7b:abc123", "archived" => false, ...}}
  """
  @spec unarchive_fine_tuned_model(client(), String.t()) :: response()
  def unarchive_fine_tuned_model(%__MODULE__{} = client, model_id) when is_binary(model_id) do
    client
    |> req(:delete, "/fine_tuning/models/#{model_id}/archive")
    |> res()
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

  @doc """
  Lists all uploaded files.

  ## Options

  #{doc(:list_files_opts)}

  ## Examples

      iex> Mistral.list_files(client)
      {:ok, %{"object" => "list", "data" => [%{"id" => "file-abc123", ...}]}}

      iex> Mistral.list_files(client, purpose: "ocr", page_size: 10)
      {:ok, %{"object" => "list", "data" => [...]}}
  """
  @spec list_files(client(), keyword()) :: response()
  def list_files(%__MODULE__{} = client, opts \\ []) when is_list(opts) do
    with {:ok, opts} <- NimbleOptions.validate(opts, schema(:list_files_opts)) do
      client
      |> req(:get, "/files", params: opts)
      |> res()
    end
  end

  @doc """
  Deletes a file by its ID.

  ## Parameters

    - `client`: A `Mistral.client()` struct.
    - `file_id`: The ID of the file to delete.

  ## Examples

      iex> Mistral.delete_file(client, "file-abc123")
      {:ok, %{"id" => "file-abc123", "object" => "file", "deleted" => true}}
  """
  @spec delete_file(client(), String.t()) :: response()
  def delete_file(%__MODULE__{} = client, file_id) when is_binary(file_id) do
    client
    |> req(:delete, "/files/#{file_id}")
    |> res()
  end

  @doc """
  Downloads the content of a file by its ID.

  Returns the raw binary content of the file.

  ## Parameters

    - `client`: A `Mistral.client()` struct.
    - `file_id`: The ID of the file to download.

  ## Examples

      iex> Mistral.download_file(client, "file-abc123")
      {:ok, <<...>>}
  """
  @spec download_file(client(), String.t()) :: response()
  def download_file(%__MODULE__{} = client, file_id) when is_binary(file_id) do
    client
    |> req(:get, "/files/#{file_id}/content")
    |> res()
  end

  defp expand_list_params(opts) do
    Enum.flat_map(opts, fn
      {key, values} when is_list(values) -> Enum.map(values, &{key, &1})
      pair -> [pair]
    end)
  end

  defp read_file(file_path) do
    case File.read(file_path) do
      {:ok, data} ->
        {:ok, data}

      {:error, reason} when is_atom(reason) ->
        {:error, %File.Error{reason: reason, action: "read file", path: file_path}}
    end
  end

  defp validate_response_format(params) do
    case Keyword.get(params, :response_format) do
      %{type: "json_schema"} = format when not is_map_key(format, :json_schema) ->
        {:error,
         %NimbleOptions.ValidationError{
           message: "json_schema is required when response_format.type is 'json_schema'",
           key: [:response_format, :json_schema]
         }}

      %{type: "json_schema", json_schema: nil} ->
        {:error,
         %NimbleOptions.ValidationError{
           message: "json_schema cannot be nil when response_format.type is 'json_schema'",
           key: [:response_format, :json_schema]
         }}

      _ ->
        :ok
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

      ## Structured Output for OCR

      You can extract structured information from documents using annotation formats:

      iex> # Extract structured data from bounding boxes
      iex> bbox_schema = %{
      ...>   type: "object",
      ...>   title: "BoundingBoxData",
      ...>   properties: %{
      ...>     text: %{type: "string", title: "Text"},
      ...>     confidence: %{type: "number", title: "Confidence", minimum: 0, maximum: 1}
      ...>   },
      ...>   additionalProperties: false
      ...> }
      iex> Mistral.ocr(client,
      ...>   model: "mistral-ocr-latest",
      ...>   document: %{type: "document_url", document_url: "https://example.com/invoice.pdf"},
      ...>   bbox_annotation_format: %{
      ...>     type: "json_schema",
      ...>     json_schema: %{name: "bbox_data", schema: bbox_schema}
      ...>   }
      ...> )

      iex> # Extract document-level structured information
      iex> doc_schema = %{
      ...>   type: "object",
      ...>   title: "DocumentInfo",
      ...>   properties: %{
      ...>     title: %{type: "string", title: "Title"},
      ...>     summary: %{type: "string", title: "Summary"},
      ...>     total_pages: %{type: "integer", title: "TotalPages"}
      ...>   },
      ...>   additionalProperties: false
      ...> }
      iex> Mistral.ocr(client,
      ...>   model: "mistral-ocr-latest",
      ...>   document: %{type: "document_url", document_url: "https://example.com/report.pdf"},
      ...>   document_annotation_format: %{
      ...>     type: "json_schema",
      ...>     json_schema: %{name: "document_info", schema: doc_schema}
      ...>   }
      ...> )

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
  Create a new conversation.

  ## Options

  #{doc(:create_conversation)}

  ## Examples

      iex> Mistral.create_conversation(client, inputs: "Hello!")
      {:ok, %{"object" => "conversation.response", "conversation_id" => "conv_abc123", ...}}

      # Stream the response
      iex> {:ok, stream} = Mistral.create_conversation(client, inputs: "Hello!", stream: true)
      iex> Enum.to_list(stream)
      [%{"object" => "conversation.response.started", ...}, ...]
  """
  @spec create_conversation(client(), keyword()) :: response()
  def create_conversation(%__MODULE__{} = client, params) when is_list(params) do
    with {:ok, params} <- NimbleOptions.validate(params, schema(:create_conversation)) do
      {stream_opt, params} = Keyword.pop(params, :stream, false)

      if stream_opt do
        params = Keyword.put(params, :stream, true)
        dest = if is_pid(stream_opt), do: stream_opt, else: self()

        task =
          Task.async(fn ->
            client
            |> req(:post, "/conversations",
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
        |> req(:post, "/conversations", json: Enum.into(params, %{}))
        |> res()
      end
    end
  end

  @doc """
  List conversations with optional pagination.

  ## Options

  #{doc(:list_conversations_opts)}

  ## Examples

      iex> Mistral.list_conversations(client)
      {:ok, [%{"object" => "conversation", ...}]}

      iex> Mistral.list_conversations(client, page: 0, page_size: 10)
      {:ok, [%{"object" => "conversation", ...}]}
  """
  @spec list_conversations(client(), keyword()) :: response()
  def list_conversations(%__MODULE__{} = client, opts \\ []) when is_list(opts) do
    with {:ok, opts} <- NimbleOptions.validate(opts, schema(:list_conversations_opts)) do
      client
      |> req(:get, "/conversations", params: opts)
      |> res()
    end
  end

  @doc """
  Retrieve a conversation by its ID.

  ## Examples

      iex> Mistral.get_conversation(client, "conv_abc123")
      {:ok, %{"object" => "conversation", "conversation_id" => "conv_abc123", ...}}
  """
  @spec get_conversation(client(), String.t()) :: response()
  def get_conversation(%__MODULE__{} = client, conversation_id)
      when is_binary(conversation_id) do
    client
    |> req(:get, "/conversations/#{conversation_id}")
    |> res()
  end

  @doc """
  Delete a conversation by its ID.

  ## Examples

      iex> Mistral.delete_conversation(client, "conv_abc123")
      {:ok, %{}}
  """
  @spec delete_conversation(client(), String.t()) :: response()
  def delete_conversation(%__MODULE__{} = client, conversation_id)
      when is_binary(conversation_id) do
    client
    |> req(:delete, "/conversations/#{conversation_id}")
    |> res()
  end

  @doc """
  Append entries to an existing conversation.

  ## Options

  #{doc(:append_conversation)}

  ## Examples

      iex> Mistral.append_conversation(client, "conv_abc123", inputs: "Follow up question")
      {:ok, %{"object" => "conversation.response", ...}}

      # Stream the response
      iex> {:ok, stream} = Mistral.append_conversation(client, "conv_abc123", inputs: "Follow up", stream: true)
      iex> Enum.to_list(stream)
      [%{"object" => "conversation.response.started", ...}, ...]
  """
  @spec append_conversation(client(), String.t(), keyword()) :: response()
  def append_conversation(%__MODULE__{} = client, conversation_id, params)
      when is_binary(conversation_id) and is_list(params) do
    with {:ok, params} <- NimbleOptions.validate(params, schema(:append_conversation)) do
      {stream_opt, params} = Keyword.pop(params, :stream, false)

      if stream_opt do
        params = Keyword.put(params, :stream, true)
        dest = if is_pid(stream_opt), do: stream_opt, else: self()

        task =
          Task.async(fn ->
            client
            |> req(:post, "/conversations/#{conversation_id}",
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
        |> req(:post, "/conversations/#{conversation_id}", json: Enum.into(params, %{}))
        |> res()
      end
    end
  end

  @doc """
  Get the history of a conversation.

  ## Examples

      iex> Mistral.get_conversation_history(client, "conv_abc123")
      {:ok, %{"entries" => [...]}}
  """
  @spec get_conversation_history(client(), String.t()) :: response()
  def get_conversation_history(%__MODULE__{} = client, conversation_id)
      when is_binary(conversation_id) do
    client
    |> req(:get, "/conversations/#{conversation_id}/history")
    |> res()
  end

  @doc """
  Get the messages of a conversation.

  ## Examples

      iex> Mistral.get_conversation_messages(client, "conv_abc123")
      {:ok, %{"messages" => [...]}}
  """
  @spec get_conversation_messages(client(), String.t()) :: response()
  def get_conversation_messages(%__MODULE__{} = client, conversation_id)
      when is_binary(conversation_id) do
    client
    |> req(:get, "/conversations/#{conversation_id}/messages")
    |> res()
  end

  @doc """
  Restart a conversation from a specific entry.

  ## Options

  #{doc(:restart_conversation)}

  ## Examples

      iex> Mistral.restart_conversation(client, "conv_abc123",
      ...>   inputs: "Try again",
      ...>   from_entry_id: "entry_xyz789"
      ...> )
      {:ok, %{"object" => "conversation.response", ...}}

      # Stream the response
      iex> {:ok, stream} = Mistral.restart_conversation(client, "conv_abc123",
      ...>   inputs: "Try again",
      ...>   from_entry_id: "entry_xyz789",
      ...>   stream: true
      ...> )
      iex> Enum.to_list(stream)
      [%{"object" => "conversation.response.started", ...}, ...]
  """
  @spec restart_conversation(client(), String.t(), keyword()) :: response()
  def restart_conversation(%__MODULE__{} = client, conversation_id, params)
      when is_binary(conversation_id) and is_list(params) do
    with {:ok, params} <- NimbleOptions.validate(params, schema(:restart_conversation)) do
      {stream_opt, params} = Keyword.pop(params, :stream, false)

      if stream_opt do
        params = Keyword.put(params, :stream, true)
        dest = if is_pid(stream_opt), do: stream_opt, else: self()

        task =
          Task.async(fn ->
            client
            |> req(:post, "/conversations/#{conversation_id}/restart",
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
        |> req(:post, "/conversations/#{conversation_id}/restart", json: Enum.into(params, %{}))
        |> res()
      end
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

  @doc """
  Delete a model by its ID.

  ## Examples

      iex> Mistral.delete_model(client, "ft:open-mistral-7b:abc123")
      {:ok, %{"id" => "ft:open-mistral-7b:abc123", "deleted" => true, ...}}
  """
  @spec delete_model(client(), String.t()) :: response()
  def delete_model(%__MODULE__{} = client, model_id) when is_binary(model_id) do
    client
    |> req(:delete, "/models/#{model_id}")
    |> res()
  end

  @doc """
  Create an agent.

  ## Options

  #{doc(:create_agent)}

  ## Agent tool structure

  #{doc(:agent_tool)}

  ## Completion arguments structure

  #{doc(:completion_args)}

  ## Examples

      iex> Mistral.create_agent(client,
      ...>   model: "mistral-large-latest",
      ...>   name: "My Agent",
      ...>   instructions: "You are a helpful assistant."
      ...> )
      {:ok, %{"id" => "ag_abc123", "name" => "My Agent", ...}}
  """
  @spec create_agent(client(), keyword()) :: response()
  def create_agent(%__MODULE__{} = client, params) when is_list(params) do
    with {:ok, params} <- NimbleOptions.validate(params, schema(:create_agent)) do
      client
      |> req(:post, "/agents", json: Enum.into(params, %{}))
      |> res()
    end
  end

  @doc """
  List agents with optional filtering and pagination.

  ## Options

  #{doc(:list_agents)}

  ## Examples

      iex> Mistral.list_agents(client)
      {:ok, %{"object" => "list", "data" => [...], "total" => 2}}

      iex> Mistral.list_agents(client, page: 0, page_size: 10)
      {:ok, %{"object" => "list", "data" => [...], "total" => 2}}
  """
  @spec list_agents(client(), keyword()) :: response()
  def list_agents(%__MODULE__{} = client, opts \\ []) when is_list(opts) do
    with {:ok, opts} <- NimbleOptions.validate(opts, schema(:list_agents)) do
      client
      |> req(:get, "/agents", params: expand_list_params(opts))
      |> res()
    end
  end

  @doc """
  Retrieve an agent by its ID.

  ## Options

  #{doc(:get_agent_opts)}

  ## Examples

      iex> Mistral.get_agent(client, "ag_abc123")
      {:ok, %{"id" => "ag_abc123", "name" => "My Agent", ...}}

      iex> Mistral.get_agent(client, "ag_abc123", agent_version: 2)
      {:ok, %{"id" => "ag_abc123", "version" => 2, ...}}
  """
  @spec get_agent(client(), String.t(), keyword()) :: response()
  def get_agent(%__MODULE__{} = client, agent_id, opts \\ [])
      when is_binary(agent_id) and is_list(opts) do
    with {:ok, opts} <- NimbleOptions.validate(opts, schema(:get_agent_opts)) do
      client
      |> req(:get, "/agents/#{agent_id}", params: opts)
      |> res()
    end
  end

  @doc """
  Update an agent. Creates a new version of the agent.

  ## Options

  #{doc(:update_agent)}

  ## Examples

      iex> Mistral.update_agent(client, "ag_abc123",
      ...>   name: "Updated Agent",
      ...>   instructions: "New instructions."
      ...> )
      {:ok, %{"id" => "ag_abc123", "name" => "Updated Agent", ...}}
  """
  @spec update_agent(client(), String.t(), keyword()) :: response()
  def update_agent(%__MODULE__{} = client, agent_id, params)
      when is_binary(agent_id) and is_list(params) do
    with {:ok, params} <- NimbleOptions.validate(params, schema(:update_agent)) do
      client
      |> req(:patch, "/agents/#{agent_id}", json: Enum.into(params, %{}))
      |> res()
    end
  end

  @doc """
  Delete an agent by its ID.

  ## Examples

      iex> Mistral.delete_agent(client, "ag_abc123")
      {:ok, %{}}
  """
  @spec delete_agent(client(), String.t()) :: response()
  def delete_agent(%__MODULE__{} = client, agent_id) when is_binary(agent_id) do
    client
    |> req(:delete, "/agents/#{agent_id}")
    |> res()
  end

  @doc """
  Switch an agent to a specific version.

  ## Examples

      iex> Mistral.update_agent_version(client, "ag_abc123", 2)
      {:ok, %{"id" => "ag_abc123", "version" => 2, ...}}
  """
  @spec update_agent_version(client(), String.t(), integer()) :: response()
  def update_agent_version(%__MODULE__{} = client, agent_id, version)
      when is_binary(agent_id) and is_integer(version) do
    client
    |> req(:patch, "/agents/#{agent_id}/version", json: %{version: version})
    |> res()
  end

  @doc """
  List all versions of an agent.

  ## Options

  #{doc(:list_agent_versions)}

  ## Examples

      iex> Mistral.list_agent_versions(client, "ag_abc123")
      {:ok, %{"object" => "list", "data" => [...], "total" => 3}}
  """
  @spec list_agent_versions(client(), String.t(), keyword()) :: response()
  def list_agent_versions(%__MODULE__{} = client, agent_id, opts \\ [])
      when is_binary(agent_id) and is_list(opts) do
    with {:ok, opts} <- NimbleOptions.validate(opts, schema(:list_agent_versions)) do
      client
      |> req(:get, "/agents/#{agent_id}/versions", params: opts)
      |> res()
    end
  end

  @doc """
  Get a specific version of an agent.

  ## Examples

      iex> Mistral.get_agent_version(client, "ag_abc123", 2)
      {:ok, %{"id" => "ag_abc123", "version" => 2, ...}}
  """
  @spec get_agent_version(client(), String.t(), integer()) :: response()
  def get_agent_version(%__MODULE__{} = client, agent_id, version)
      when is_binary(agent_id) and is_integer(version) do
    client
    |> req(:get, "/agents/#{agent_id}/versions/#{version}")
    |> res()
  end

  @doc """
  Create or update a version alias for an agent.

  ## Examples

      iex> Mistral.create_or_update_agent_alias(client, "ag_abc123", "production", 2)
      {:ok, %{"alias" => "production", "version" => 2, ...}}
  """
  @spec create_or_update_agent_alias(client(), String.t(), String.t(), integer()) :: response()
  def create_or_update_agent_alias(%__MODULE__{} = client, agent_id, alias_name, version)
      when is_binary(agent_id) and is_binary(alias_name) and is_integer(version) do
    client
    |> req(:put, "/agents/#{agent_id}/aliases", json: %{alias: alias_name, version: version})
    |> res()
  end

  @doc """
  List all version aliases for an agent.

  ## Examples

      iex> Mistral.list_agent_aliases(client, "ag_abc123")
      {:ok, %{"object" => "list", "data" => [...], "total" => 2}}
  """
  @spec list_agent_aliases(client(), String.t()) :: response()
  def list_agent_aliases(%__MODULE__{} = client, agent_id) when is_binary(agent_id) do
    client
    |> req(:get, "/agents/#{agent_id}/aliases")
    |> res()
  end

  @doc """
  Send a completion request to an agent.

  ## Options

  #{doc(:agent_completion)}

  ## Examples

      iex> Mistral.agent_completion(client,
      ...>   agent_id: "ag_abc123",
      ...>   messages: [%{role: "user", content: "Hello!"}]
      ...> )
      {:ok, %{"choices" => [%{"message" => %{"content" => "..."}}], ...}}

      # Stream the response
      iex> {:ok, stream} = Mistral.agent_completion(client,
      ...>   agent_id: "ag_abc123",
      ...>   messages: [%{role: "user", content: "Hello!"}],
      ...>   stream: true
      ...> )
      iex> Enum.to_list(stream)
      [%{"choices" => [%{"delta" => ...}]}, ...]
  """
  @spec agent_completion(client(), keyword()) :: response()
  def agent_completion(%__MODULE__{} = client, params) when is_list(params) do
    with {:ok, params} <- NimbleOptions.validate(params, schema(:agent_completion)) do
      {stream_opt, params} = Keyword.pop(params, :stream, false)

      if stream_opt do
        params = Keyword.put(params, :stream, true)
        dest = if is_pid(stream_opt), do: stream_opt, else: self()

        task =
          Task.async(fn ->
            client
            |> req(:post, "/agents/completions",
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
        |> req(:post, "/agents/completions", json: Enum.into(params, %{}))
        |> res()
      end
    end
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
