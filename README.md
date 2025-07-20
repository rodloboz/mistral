# Mistral

[![Hex.pm Version](https://img.shields.io/hexpm/v/mistral)](https://hex.pm/packages/mistral)
[![Hex.pm Download Total](https://img.shields.io/hexpm/dt/mistral)](https://hex.pm/packages/mistral)
![GitHub CI](https://github.com/rodloboz/mistral/actions/workflows/all-checks-pass.yml/badge.svg)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Mistral is an open-source Elixir client for the [Mistral AI API](https://docs.mistral.ai/api/), offering a simple and efficient way to integrate Mistral's language models into your Elixir applications. Designed for ease of use, Mistral provides access to Mistral AI's capabilities, making it a great choice for building AI-driven features.

## Features

- 💬 Chat Completions
- 🛠 Function Calling / Tool Use
- 🔢 Embeddings
- 🌊 Streaming Support
- 🛡️ Error Handling
- ⬆️ File Uploading
- 📄 OCR (Optical Character Recognition)
- 🤖 Models

## Installation

Add `mistral` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:mistral, "~> 0.3.0"}
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

### Streaming Chat

```elixir
{:ok, stream} = Mistral.chat(client,
  model: "mistral-small-latest",
  messages: [
    %{role: "user", content: "Tell me a short story"}
  ],
  stream: true
)

stream
|> Stream.each(fn chunk -> IO.write(chunk["choices"][0]["delta"]["content"] || "") end)
|> Stream.run()
```

### Embeddings

```elixir
{:ok, embeddings} = Mistral.embed(client,
  input: ["Hello, world!", "This is an embedding test"]
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
- [ ] Classification/Moderation API
- [ ] Batch Processing Support
- [ ] Complete File Operations (list, delete, download)
- [ ] Advanced Streaming Improvements

## License

This project is licensed under the MIT License.

## Disclaimer

This is an independent, community-supported library and is not officially associated with Mistral AI.
