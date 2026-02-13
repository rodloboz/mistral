# Mistral

[![Hex.pm Version](https://img.shields.io/hexpm/v/mistral)](https://hex.pm/packages/mistral)
[![Hex.pm Download Total](https://img.shields.io/hexpm/dt/mistral)](https://hex.pm/packages/mistral)
![GitHub CI](https://github.com/rodloboz/mistral/actions/workflows/all-checks-pass.yml/badge.svg)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Mistral is an open-source Elixir client for the [Mistral AI API](https://docs.mistral.ai/api/), offering a simple and efficient way to integrate Mistral's language models into your Elixir applications. Designed for ease of use, Mistral provides access to Mistral AI's capabilities, making it a great choice for building AI-driven features.

## Features

- 💬 Chat Completions
- 🛠 Function Calling / Tool Use
- ✏️ FIM (Fill-in-the-Middle) Code Completions
- 🔢 Embeddings + Embedding Utilities (`Mistral.Embeddings`)
- 🌊 Streaming Support + Streaming Utilities (`Mistral.Streaming`)
- 💬 Conversations API + Conversation Utilities (`Mistral.Conversations`)
- 🤖 Agents API
- 🏷️ Classification & Moderation
- 📦 Batch Processing
- 🎯 Fine-tuning
- 📁 File Operations (upload, download, list, delete)
- 📄 OCR (Optical Character Recognition)
- 🧩 Models
- 🗄️ Response Caching (`Mistral.Cache`)
- 🔄 Automatic Retry with Exponential Backoff
- 🛡️ Error Handling

## Installation

Add `mistral` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:mistral, "~> 0.5.0"}
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
client = Mistral.init("your_api_key")

{:ok, response} = Mistral.chat(client,
  model: "mistral-small-latest",
  messages: [
    %{role: "user", content: "Write a haiku about elixir"}
  ]
)
```

### Streaming Chat

```elixir
{:ok, stream} = Mistral.chat(client,
  model: "mistral-small-latest",
  messages: [
    %{role: "user", content: "Tell me a short story"}
  ],
  stream: true
)

# Collect all streamed content into a single string
{:ok, content} = Mistral.Streaming.collect_content(stream)
```

### FIM (Fill-in-the-Middle) Completion

```elixir
{:ok, response} = Mistral.fim(client,
  model: "codestral-latest",
  prompt: "def fibonacci(n):\n    ",
  suffix: "\n    return result"
)
```

### Embeddings

```elixir
{:ok, response} = Mistral.embed(client,
  input: ["Hello, world!", "This is an embedding test"]
)

# Compute cosine similarity between two embeddings
[emb1, emb2] = Mistral.Embeddings.extract_embeddings(response)
similarity = Mistral.Embeddings.cosine_similarity(emb1, emb2)
```

### Conversations

```elixir
{:ok, response} = Mistral.create_conversation(client,
  inputs: "What is the capital of France?",
  model: "mistral-small-latest"
)

conversation_id = Mistral.Conversations.extract_conversation_id(response)

{:ok, followup} = Mistral.append_conversation(client, conversation_id,
  inputs: "And what about Germany?"
)
```

### Agent Completion

```elixir
{:ok, response} = Mistral.agent_completion(client,
  agent_id: "your_agent_id",
  messages: [
    %{role: "user", content: "Help me with this task"}
  ]
)
```

### Classification

```elixir
{:ok, result} = Mistral.classify(client,
  model: "mistral-moderation-latest",
  inputs: ["Some text to classify"]
)
```

### Response Format Control

Control the output format for structured responses:

```elixir
# JSON Object Mode - ensures valid JSON response
{:ok, response} = Mistral.chat(client,
  model: "mistral-small-latest",
  messages: [
    %{role: "user", content: "Generate a user profile in JSON format"}
  ],
  response_format: %{type: "json_object"}
)

# JSON Schema Mode - validates response against schema
user_schema = %{
  type: "object",
  title: "UserProfile",
  properties: %{
    name: %{type: "string", title: "Name"},
    age: %{type: "integer", title: "Age", minimum: 0},
    email: %{type: "string", title: "Email"}
  },
  required: ["name", "age"],
  additionalProperties: false
}

{:ok, response} = Mistral.chat(client,
  model: "mistral-small-latest",
  messages: [
    %{role: "user", content: "Generate a user profile"}
  ],
  response_format: %{
    type: "json_schema",
    json_schema: %{
      name: "user_profile",
      schema: user_schema,
      strict: true
    }
  }
)
```

### Response Caching

Enable caching to avoid redundant API calls for deterministic endpoints:

```elixir
client = Mistral.init("your_api_key", cache: true, cache_ttl: :timer.minutes(10))

# Repeated calls to deterministic endpoints (embeddings, classifications, etc.)
# will be served from cache
{:ok, response} = Mistral.embed(client, input: ["Hello, world!"])
```

## Credits & Acknowledgments

This package was heavily inspired by and draws from the excellent implementations of:

- [Ollama](https://github.com/lebrunel/ollama-ex) by [lebrunel](https://github.com/lebrunel)
- [Antropix](https://github.com/lebrunel/anthropix) by [lebrunel](https://github.com/lebrunel)

A huge thanks to the author of these projects for their work in creating robust and well-structured Elixir clients for AI APIs. Their implementations served as a valuable reference in designing this library.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Roadmap

- [X] OCR (Optical Character Recognition) Support
- [X] Enhanced Error Handling
- [X] Response Format Control (JSON mode with schema validation)
- [X] Classification/Moderation API
- [X] Batch Processing Support
- [X] Complete File Operations (list, delete, download)
- [X] Advanced Streaming Improvements
- [X] Conversations API
- [X] Agents API
- [X] Fine-tuning API
- [X] Response Caching
- [X] Automatic Retry with Exponential Backoff
- [ ] Guardrails API
- [ ] Connectors API
- [ ] Async Client Support

## License

This project is licensed under the MIT License.

## Disclaimer

This is an independent, community-supported library and is not officially associated with Mistral AI.
