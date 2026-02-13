defmodule Mistral.Mock do
  @moduledoc false

  alias Plug.Conn.Status
  import Plug.Conn

  @mocks_key :mistral_mocks

  @default_mocks %{
    chat_completion: %{
      "id" => "cmpl-e5cc70bb28c444948073e77776eb30ef",
      "object" => "chat.completion",
      "created" => 1_702_256_327,
      "model" => "mistral-small-latest",
      "choices" => [
        %{
          "index" => 0,
          "message" => %{
            "role" => "assistant",
            "content" =>
              "Waves crash against stone\nEchoes through eternal time\nNature's harmony"
          },
          "finish_reason" => "stop"
        }
      ],
      "usage" => %{
        "prompt_tokens" => 16,
        "completion_tokens" => 18,
        "total_tokens" => 34
      }
    },
    tool_use: %{
      "id" => "cmpl-tool-use-example",
      "object" => "chat.completion",
      "created" => 1_702_256_328,
      "model" => "mistral-large-latest",
      "choices" => [
        %{
          "index" => 0,
          "message" => %{
            "role" => "assistant",
            "content" => "",
            "tool_calls" => [
              %{
                "type" => "function",
                "function" => %{
                  "name" => "jay_dilla_facts",
                  "arguments" => %{
                    "question" => "Why is *Donuts* considered a masterpiece?"
                  }
                }
              }
            ]
          },
          "finish_reason" => "tool_calls"
        }
      ],
      "usage" => %{
        "prompt_tokens" => 20,
        "completion_tokens" => 15,
        "total_tokens" => 35
      }
    },
    embedding: %{
      "id" => "emb-123456",
      "object" => "list",
      "data" => [
        %{
          "object" => "embedding",
          "embedding" => [
            0.1234,
            0.5678,
            0.9012,
            0.3456,
            0.7890,
            0.2345,
            0.6789,
            0.0123,
            0.4567,
            0.8901
          ],
          "index" => 0
        }
      ],
      "model" => "mistral-embed",
      "usage" => %{
        "prompt_tokens" => 8,
        "total_tokens" => 8
      }
    },
    embeddings: %{
      "id" => "emb-123456",
      "object" => "list",
      "data" => [
        %{
          "object" => "embedding",
          "embedding" => [
            0.1234,
            0.5678,
            0.9012,
            0.3456,
            0.7890,
            0.2345,
            0.6789,
            0.0123,
            0.4567,
            0.8901
          ],
          "index" => 0
        },
        %{
          "object" => "embedding",
          "embedding" => [
            0.4321,
            0.8765,
            0.2109,
            0.6543,
            0.0987,
            0.5432,
            0.9876,
            0.3210,
            0.7654,
            0.1098
          ],
          "index" => 1
        }
      ],
      "model" => "mistral-embed",
      "usage" => %{
        "prompt_tokens" => 16,
        "total_tokens" => 16
      }
    },
    file_upload: %{
      "id" => "file-abc123",
      "object" => "file",
      "bytes" => 12345,
      "created_at" => 1_741_023_462,
      "filename" => "dummy.pdf",
      "purpose" => "ocr",
      "sample_type" => "ocr_input",
      "source" => "upload",
      "deleted" => false,
      "num_lines" => nil
    },
    file_list: %{
      "object" => "list",
      "data" => [
        %{
          "id" => "file-abc123",
          "object" => "file",
          "bytes" => 12_345,
          "created_at" => 1_741_023_462,
          "filename" => "training_data.jsonl",
          "purpose" => "fine-tune",
          "sample_type" => "pretrain",
          "source" => "upload",
          "deleted" => false,
          "num_lines" => 100
        },
        %{
          "id" => "file-def456",
          "object" => "file",
          "bytes" => 67_890,
          "created_at" => 1_741_023_500,
          "filename" => "document.pdf",
          "purpose" => "ocr",
          "sample_type" => "ocr_input",
          "source" => "upload",
          "deleted" => false,
          "num_lines" => nil
        }
      ],
      "total" => 2
    },
    file_delete: %{
      "id" => "file-abc123",
      "object" => "file",
      "deleted" => true
    },
    ocr: %{
      "model" => "mistral-ocr-latest",
      "pages" => [
        %{
          "index" => 0,
          "markdown" => "some content",
          "images" => [
            %{
              "id" => "img-123456",
              "top_left_x" => 0,
              "top_left_y" => 0,
              "bottom_right_x" => 0,
              "bottom_right_y" => 0,
              "image_base64" => "base64representation"
            }
          ],
          "dimensions" => %{
            "dpi" => 0,
            "height" => 0,
            "width" => 0
          }
        }
      ],
      "usage_info" => %{
        "pages_processed" => 0,
        "doc_size_bytes" => 0
      }
    },
    classification: %{
      "id" => "clf-abc123",
      "model" => "mistral-moderation-latest",
      "results" => [
        %{
          "categories" => %{},
          "category_scores" => %{
            "sexual" => 0.01,
            "hate_and_discrimination" => 0.02,
            "violence_and_threats" => 0.01,
            "dangerous_and_criminal_content" => 0.0,
            "selfharm" => 0.0,
            "health" => 0.0,
            "financial" => 0.0,
            "law" => 0.0,
            "pii" => 0.0
          }
        }
      ]
    },
    classifications: %{
      "id" => "clf-abc123",
      "model" => "mistral-moderation-latest",
      "results" => [
        %{
          "categories" => %{},
          "category_scores" => %{
            "sexual" => 0.01,
            "hate_and_discrimination" => 0.02,
            "violence_and_threats" => 0.01,
            "dangerous_and_criminal_content" => 0.0,
            "selfharm" => 0.0,
            "health" => 0.0,
            "financial" => 0.0,
            "law" => 0.0,
            "pii" => 0.0
          }
        },
        %{
          "categories" => %{},
          "category_scores" => %{
            "sexual" => 0.05,
            "hate_and_discrimination" => 0.03,
            "violence_and_threats" => 0.02,
            "dangerous_and_criminal_content" => 0.01,
            "selfharm" => 0.0,
            "health" => 0.0,
            "financial" => 0.0,
            "law" => 0.0,
            "pii" => 0.0
          }
        }
      ]
    },
    moderation: %{
      "id" => "mod-abc123",
      "model" => "mistral-moderation-latest",
      "results" => [
        %{
          "categories" => %{
            "sexual" => false,
            "hate_and_discrimination" => false,
            "violence_and_threats" => false,
            "dangerous_and_criminal_content" => false,
            "selfharm" => false,
            "health" => false,
            "financial" => false,
            "law" => false,
            "pii" => false
          },
          "category_scores" => %{
            "sexual" => 0.01,
            "hate_and_discrimination" => 0.02,
            "violence_and_threats" => 0.01,
            "dangerous_and_criminal_content" => 0.0,
            "selfharm" => 0.0,
            "health" => 0.0,
            "financial" => 0.0,
            "law" => 0.0,
            "pii" => 0.0
          }
        }
      ]
    },
    moderations: %{
      "id" => "mod-abc123",
      "model" => "mistral-moderation-latest",
      "results" => [
        %{
          "categories" => %{
            "sexual" => false,
            "hate_and_discrimination" => false,
            "violence_and_threats" => false,
            "dangerous_and_criminal_content" => false,
            "selfharm" => false,
            "health" => false,
            "financial" => false,
            "law" => false,
            "pii" => false
          },
          "category_scores" => %{
            "sexual" => 0.01,
            "hate_and_discrimination" => 0.02,
            "violence_and_threats" => 0.01,
            "dangerous_and_criminal_content" => 0.0,
            "selfharm" => 0.0,
            "health" => 0.0,
            "financial" => 0.0,
            "law" => 0.0,
            "pii" => 0.0
          }
        },
        %{
          "categories" => %{
            "sexual" => false,
            "hate_and_discrimination" => false,
            "violence_and_threats" => false,
            "dangerous_and_criminal_content" => false,
            "selfharm" => false,
            "health" => false,
            "financial" => false,
            "law" => false,
            "pii" => false
          },
          "category_scores" => %{
            "sexual" => 0.05,
            "hate_and_discrimination" => 0.03,
            "violence_and_threats" => 0.02,
            "dangerous_and_criminal_content" => 0.01,
            "selfharm" => 0.0,
            "health" => 0.0,
            "financial" => 0.0,
            "law" => 0.0,
            "pii" => 0.0
          }
        }
      ]
    }
  }

  @stream_mocks %{
    chat_completion: [
      %{
        "id" => "cmpl-e5cc70bb28c444948073e77776eb30ef",
        "object" => "chat.completion.chunk",
        "created" => 1_702_256_327,
        "model" => "mistral-small-latest",
        "choices" => [
          %{
            "index" => 0,
            "delta" => %{"role" => "assistant"},
            "finish_reason" => nil
          }
        ]
      },
      %{
        "id" => "cmpl-e5cc70bb28c444948073e77776eb30ef",
        "object" => "chat.completion.chunk",
        "created" => 1_702_256_327,
        "model" => "mistral-small-latest",
        "choices" => [
          %{
            "index" => 0,
            "delta" => %{"content" => "Waves crash against stone"},
            "finish_reason" => nil
          }
        ]
      },
      %{
        "id" => "cmpl-e5cc70bb28c444948073e77776eb30ef",
        "object" => "chat.completion.chunk",
        "created" => 1_702_256_327,
        "model" => "mistral-small-latest",
        "choices" => [
          %{
            "index" => 0,
            "delta" => %{"content" => "\nEchoes through eternal time"},
            "finish_reason" => nil
          }
        ]
      },
      %{
        "id" => "cmpl-e5cc70bb28c444948073e77776eb30ef",
        "object" => "chat.completion.chunk",
        "created" => 1_702_256_327,
        "model" => "mistral-small-latest",
        "choices" => [
          %{
            "index" => 0,
            "delta" => %{"content" => "\nNature's harmony"},
            "finish_reason" => "stop"
          }
        ],
        "usage" => %{
          "prompt_tokens" => 16,
          "completion_tokens" => 18,
          "total_tokens" => 34
        }
      }
    ],
    tool_use: [
      %{
        "id" => "cmpl-tool-use-example",
        "object" => "chat.completion",
        "created" => 1_702_256_328,
        "model" => "mistral-large-latest",
        "choices" => [
          %{
            "index" => 0,
            "message" => %{
              "role" => "assistant",
              "content" => "",
              "tool_calls" => [
                %{
                  "type" => "function",
                  "function" => %{
                    "name" => "jay_dilla_facts",
                    "arguments" => %{
                      "question" => "Why is *Donuts* considered a masterpiece?"
                    }
                  }
                }
              ]
            },
            "finish_reason" => "tool_calls"
          }
        ],
        "usage" => %{
          "prompt_tokens" => 20,
          "completion_tokens" => 15,
          "total_tokens" => 35
        }
      }
    ],
    embedding: %{
      "id" => "emb-123456",
      "object" => "list",
      "data" => [
        %{
          "object" => "embedding",
          "embedding" => [
            0.1234,
            0.5678,
            0.9012,
            0.3456,
            0.7890,
            0.2345,
            0.6789,
            0.0123,
            0.4567,
            0.8901
          ],
          "index" => 0
        }
      ],
      "model" => "mistral-embed",
      "usage" => %{
        "prompt_tokens" => 8,
        "total_tokens" => 8
      }
    },
    embeddings: %{
      "id" => "emb-123456",
      "object" => "list",
      "data" => [
        %{
          "object" => "embedding",
          "embedding" => [
            0.1234,
            0.5678,
            0.9012,
            0.3456,
            0.7890,
            0.2345,
            0.6789,
            0.0123,
            0.4567,
            0.8901
          ],
          "index" => 0
        },
        %{
          "object" => "embedding",
          "embedding" => [
            0.4321,
            0.8765,
            0.2109,
            0.6543,
            0.0987,
            0.5432,
            0.9876,
            0.3210,
            0.7654,
            0.1098
          ],
          "index" => 1
        }
      ],
      "model" => "mistral-embed",
      "usage" => %{
        "prompt_tokens" => 16,
        "total_tokens" => 16
      }
    }
  }

  @spec add_mock(any(), any()) :: any()
  def add_mock(key, value) do
    mocks = Process.get(@mocks_key, %{})
    Process.put(@mocks_key, Map.put(mocks, key, value))
  end

  @spec get_mocks() :: %{
          :chat_completion => any(),
          :embedding => any(),
          :embeddings => any(),
          :tool_use => any(),
          :classification => any(),
          :classifications => any(),
          :moderation => any(),
          :moderations => any(),
          optional(any()) => any()
        }
  def get_mocks do
    Map.merge(@default_mocks, Process.get(@mocks_key, %{}))
  end

  @spec client(function()) :: Mistral.client()
  def client(plug) when is_function(plug, 1) do
    struct(Mistral, req: Req.new(plug: plug))
  end

  @spec respond(Plug.Conn.t(), atom() | number()) :: Plug.Conn.t()
  def respond(conn, name) when is_atom(name) do
    mocks = get_mocks()

    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, Jason.encode!(Map.get(mocks, name)))
  end

  def respond(conn, status) when is_number(status) do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(
      status,
      Jason.encode!(%{
        error: %{
          type: Status.reason_atom(status),
          message: Status.reason_phrase(status)
        }
      })
    )
  end

  @spec respond_raw(Plug.Conn.t(), binary(), String.t()) :: Plug.Conn.t()
  def respond_raw(conn, body, content_type \\ "application/octet-stream") do
    conn
    |> put_resp_header("content-type", content_type)
    |> send_resp(200, body)
  end

  @spec stream(Plug.Conn.t(), atom()) :: Plug.Conn.t()
  def stream(conn, name) when is_atom(name) do
    conn =
      conn
      |> put_resp_header("content-type", "text/event-stream")
      |> send_chunked(200)

    Enum.reduce(@stream_mocks[name], conn, fn chunk, conn ->
      {:ok, conn} = chunk(conn, "data: #{Jason.encode!(chunk)}\n\n")
      conn
    end)
    |> chunk("data: [DONE]\n\n")
    |> elem(1)
  end
end
