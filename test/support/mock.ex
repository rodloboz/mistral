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
    fim_completion: %{
      "id" => "fim-e5cc70bb28c444948073e77776eb30ef",
      "object" => "chat.completion",
      "created" => 1_702_256_327,
      "model" => "codestral-latest",
      "choices" => [
        %{
          "index" => 0,
          "message" => %{
            "role" => "assistant",
            "content" => "add(a, b):\n    return a + b"
          },
          "finish_reason" => "stop"
        }
      ],
      "usage" => %{
        "prompt_tokens" => 8,
        "completion_tokens" => 12,
        "total_tokens" => 20
      }
    },
    batch_job: %{
      "id" => "b_abc123",
      "object" => "batch",
      "input_files" => ["file-abc123"],
      "endpoint" => "/v1/chat/completions",
      "model" => "mistral-small-latest",
      "metadata" => nil,
      "output_file" => nil,
      "error_file" => nil,
      "errors" => [],
      "status" => "QUEUED",
      "created_at" => 1_702_256_327,
      "total_requests" => 2,
      "completed_requests" => 0,
      "succeeded_requests" => 0,
      "failed_requests" => 0,
      "started_at" => nil,
      "completed_at" => nil
    },
    batch_jobs: %{
      "object" => "list",
      "data" => [
        %{
          "id" => "b_abc123",
          "object" => "batch",
          "input_files" => ["file-abc123"],
          "endpoint" => "/v1/chat/completions",
          "model" => "mistral-small-latest",
          "errors" => [],
          "status" => "QUEUED",
          "created_at" => 1_702_256_327,
          "total_requests" => 2,
          "completed_requests" => 0,
          "succeeded_requests" => 0,
          "failed_requests" => 0
        },
        %{
          "id" => "b_def456",
          "object" => "batch",
          "input_files" => ["file-def456"],
          "endpoint" => "/v1/embeddings",
          "model" => "mistral-embed",
          "errors" => [],
          "status" => "SUCCESS",
          "created_at" => 1_702_256_400,
          "total_requests" => 5,
          "completed_requests" => 5,
          "succeeded_requests" => 5,
          "failed_requests" => 0
        }
      ],
      "total" => 2
    },
    batch_job_cancelled: %{
      "id" => "b_abc123",
      "object" => "batch",
      "input_files" => ["file-abc123"],
      "endpoint" => "/v1/chat/completions",
      "model" => "mistral-small-latest",
      "errors" => [],
      "status" => "CANCELLATION_REQUESTED",
      "created_at" => 1_702_256_327,
      "total_requests" => 2,
      "completed_requests" => 0,
      "succeeded_requests" => 0,
      "failed_requests" => 0
    },
    fine_tuning_job: %{
      "id" => "ft-abc123",
      "object" => "fine_tuning.job",
      "model" => "open-mistral-7b",
      "status" => "QUEUED",
      "job_type" => "completion",
      "created_at" => 1_702_256_327,
      "modified_at" => 1_702_256_327,
      "training_files" => ["file-abc123"],
      "hyperparameters" => %{
        "training_steps" => 10,
        "learning_rate" => 0.0001
      },
      "fine_tuned_model" => nil,
      "integrations" => []
    },
    fine_tuning_jobs: %{
      "object" => "list",
      "data" => [
        %{
          "id" => "ft-abc123",
          "object" => "fine_tuning.job",
          "model" => "open-mistral-7b",
          "status" => "QUEUED",
          "job_type" => "completion",
          "created_at" => 1_702_256_327,
          "modified_at" => 1_702_256_327,
          "training_files" => ["file-abc123"],
          "hyperparameters" => %{"training_steps" => 10},
          "fine_tuned_model" => nil
        },
        %{
          "id" => "ft-def456",
          "object" => "fine_tuning.job",
          "model" => "open-mistral-7b",
          "status" => "SUCCESS",
          "job_type" => "completion",
          "created_at" => 1_702_256_400,
          "modified_at" => 1_702_256_500,
          "training_files" => ["file-def456"],
          "hyperparameters" => %{"training_steps" => 100},
          "fine_tuned_model" => "ft:open-mistral-7b:my-model:abc123"
        }
      ],
      "total" => 2
    },
    fine_tuning_job_detailed: %{
      "id" => "ft-abc123",
      "object" => "fine_tuning.job",
      "model" => "open-mistral-7b",
      "status" => "RUNNING",
      "job_type" => "completion",
      "created_at" => 1_702_256_327,
      "modified_at" => 1_702_256_500,
      "training_files" => ["file-abc123"],
      "hyperparameters" => %{
        "training_steps" => 100,
        "learning_rate" => 0.0001
      },
      "fine_tuned_model" => nil,
      "integrations" => [],
      "events" => [
        %{"name" => "status-updated", "created_at" => 1_702_256_400, "data" => "RUNNING"}
      ],
      "checkpoints" => [
        %{"step_number" => 50, "metrics" => %{"train_loss" => 0.5}}
      ],
      "metadata" => %{"expected_duration_seconds" => 600}
    },
    fine_tuning_job_cancelled: %{
      "id" => "ft-abc123",
      "object" => "fine_tuning.job",
      "model" => "open-mistral-7b",
      "status" => "CANCELLATION_REQUESTED",
      "job_type" => "completion",
      "created_at" => 1_702_256_327,
      "modified_at" => 1_702_256_500,
      "training_files" => ["file-abc123"],
      "hyperparameters" => %{"training_steps" => 10},
      "fine_tuned_model" => nil
    },
    fine_tuning_job_started: %{
      "id" => "ft-abc123",
      "object" => "fine_tuning.job",
      "model" => "open-mistral-7b",
      "status" => "STARTED",
      "job_type" => "completion",
      "created_at" => 1_702_256_327,
      "modified_at" => 1_702_256_500,
      "training_files" => ["file-abc123"],
      "hyperparameters" => %{"training_steps" => 10},
      "fine_tuned_model" => nil
    },
    fine_tuning_job_dry_run: %{
      "expected_duration_seconds" => 300,
      "data_tokens" => 50_000,
      "training_tokens" => 100_000,
      "estimated_start_time" => 1_702_260_000,
      "cost" => 1.5,
      "cost_currency" => "EUR"
    },
    ft_model_updated: %{
      "id" => "ft:open-mistral-7b:my-model:abc123",
      "object" => "model",
      "created" => 1_702_256_327,
      "owned_by" => "user-abc123",
      "name" => "Updated Model Name",
      "description" => "Updated description",
      "capabilities" => %{
        "completion_chat" => true,
        "fine_tuning" => false
      },
      "max_context_length" => 32_768,
      "aliases" => []
    },
    ft_model_archived: %{
      "id" => "ft:open-mistral-7b:my-model:abc123",
      "object" => "model",
      "archived" => true
    },
    ft_model_unarchived: %{
      "id" => "ft:open-mistral-7b:my-model:abc123",
      "object" => "model",
      "archived" => false
    },
    model_deleted: %{
      "id" => "ft:open-mistral-7b:my-model:abc123",
      "object" => "model",
      "deleted" => true
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
    },
    agent: %{
      "id" => "ag_abc123",
      "object" => "agent",
      "name" => "My Agent",
      "model" => "mistral-large-latest",
      "version" => 1,
      "instructions" => "You are a helpful assistant.",
      "tools" => [],
      "completion_args" => %{},
      "description" => nil,
      "handoffs" => [],
      "metadata" => %{},
      "created_at" => 1_702_256_327,
      "updated_at" => 1_702_256_327
    },
    agents: %{
      "object" => "list",
      "data" => [
        %{
          "id" => "ag_abc123",
          "object" => "agent",
          "name" => "My Agent",
          "model" => "mistral-large-latest",
          "version" => 1,
          "created_at" => 1_702_256_327,
          "updated_at" => 1_702_256_327
        },
        %{
          "id" => "ag_def456",
          "object" => "agent",
          "name" => "Another Agent",
          "model" => "mistral-small-latest",
          "version" => 1,
          "created_at" => 1_702_256_400,
          "updated_at" => 1_702_256_400
        }
      ],
      "total" => 2
    },
    agent_alias: %{
      "agent_id" => "ag_abc123",
      "alias" => "production",
      "version" => 2,
      "created_at" => 1_702_256_327,
      "updated_at" => 1_702_256_327
    },
    agent_aliases: %{
      "object" => "list",
      "data" => [
        %{
          "agent_id" => "ag_abc123",
          "alias" => "production",
          "version" => 2,
          "created_at" => 1_702_256_327,
          "updated_at" => 1_702_256_327
        },
        %{
          "agent_id" => "ag_abc123",
          "alias" => "staging",
          "version" => 1,
          "created_at" => 1_702_256_327,
          "updated_at" => 1_702_256_327
        }
      ],
      "total" => 2
    },
    agent_completion: %{
      "id" => "cmpl-agent-abc123",
      "object" => "chat.completion",
      "created" => 1_702_256_327,
      "model" => "mistral-large-latest",
      "choices" => [
        %{
          "index" => 0,
          "message" => %{
            "role" => "assistant",
            "content" => "Hello! How can I help you today?"
          },
          "finish_reason" => "stop"
        }
      ],
      "usage" => %{
        "prompt_tokens" => 10,
        "completion_tokens" => 12,
        "total_tokens" => 22
      }
    },
    conversation_response: %{
      "object" => "conversation.response",
      "conversation_id" => "conv_abc123",
      "outputs" => [
        %{
          "type" => "message.output",
          "id" => "entry_out_001",
          "content" => "Hello! How can I help you today?",
          "role" => "assistant",
          "model" => "mistral-large-latest"
        }
      ],
      "usage" => %{
        "prompt_tokens" => 10,
        "completion_tokens" => 12,
        "total_tokens" => 22
      }
    },
    conversation_list: [
      %{
        "object" => "conversation",
        "conversation_id" => "conv_abc123",
        "model" => "mistral-large-latest",
        "name" => "Test Conversation",
        "created_at" => 1_702_256_327,
        "updated_at" => 1_702_256_327
      },
      %{
        "object" => "conversation",
        "conversation_id" => "conv_def456",
        "agent_id" => "ag_abc123",
        "name" => "Agent Conversation",
        "created_at" => 1_702_256_400,
        "updated_at" => 1_702_256_400
      }
    ],
    conversation: %{
      "object" => "conversation",
      "conversation_id" => "conv_abc123",
      "model" => "mistral-large-latest",
      "name" => "Test Conversation",
      "instructions" => "You are a helpful assistant.",
      "tools" => [],
      "created_at" => 1_702_256_327,
      "updated_at" => 1_702_256_327
    },
    conversation_history: %{
      "entries" => [
        %{
          "type" => "message.input",
          "id" => "entry_in_001",
          "content" => "Hello!",
          "role" => "user"
        },
        %{
          "type" => "message.output",
          "id" => "entry_out_001",
          "content" => "Hello! How can I help you today?",
          "role" => "assistant",
          "model" => "mistral-large-latest"
        }
      ]
    },
    conversation_messages: %{
      "messages" => [
        %{
          "role" => "user",
          "content" => "Hello!"
        },
        %{
          "role" => "assistant",
          "content" => "Hello! How can I help you today?"
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
    },
    fim_completion: [
      %{
        "id" => "fim-e5cc70bb28c444948073e77776eb30ef",
        "object" => "chat.completion.chunk",
        "created" => 1_702_256_327,
        "model" => "codestral-latest",
        "choices" => [
          %{
            "index" => 0,
            "delta" => %{"role" => "assistant"},
            "finish_reason" => nil
          }
        ]
      },
      %{
        "id" => "fim-e5cc70bb28c444948073e77776eb30ef",
        "object" => "chat.completion.chunk",
        "created" => 1_702_256_327,
        "model" => "codestral-latest",
        "choices" => [
          %{
            "index" => 0,
            "delta" => %{"content" => "add(a, b):\n"},
            "finish_reason" => nil
          }
        ]
      },
      %{
        "id" => "fim-e5cc70bb28c444948073e77776eb30ef",
        "object" => "chat.completion.chunk",
        "created" => 1_702_256_327,
        "model" => "codestral-latest",
        "choices" => [
          %{
            "index" => 0,
            "delta" => %{"content" => "    return a + b"},
            "finish_reason" => "stop"
          }
        ],
        "usage" => %{
          "prompt_tokens" => 8,
          "completion_tokens" => 12,
          "total_tokens" => 20
        }
      }
    ],
    agent_completion: [
      %{
        "id" => "cmpl-agent-abc123",
        "object" => "chat.completion.chunk",
        "created" => 1_702_256_327,
        "model" => "mistral-large-latest",
        "choices" => [
          %{
            "index" => 0,
            "delta" => %{"role" => "assistant"},
            "finish_reason" => nil
          }
        ]
      },
      %{
        "id" => "cmpl-agent-abc123",
        "object" => "chat.completion.chunk",
        "created" => 1_702_256_327,
        "model" => "mistral-large-latest",
        "choices" => [
          %{
            "index" => 0,
            "delta" => %{"content" => "Hello! How can I "},
            "finish_reason" => nil
          }
        ]
      },
      %{
        "id" => "cmpl-agent-abc123",
        "object" => "chat.completion.chunk",
        "created" => 1_702_256_327,
        "model" => "mistral-large-latest",
        "choices" => [
          %{
            "index" => 0,
            "delta" => %{"content" => "help you today?"},
            "finish_reason" => "stop"
          }
        ],
        "usage" => %{
          "prompt_tokens" => 10,
          "completion_tokens" => 12,
          "total_tokens" => 22
        }
      }
    ],
    conversation: [
      %{
        "object" => "conversation.response.started",
        "conversation_id" => "conv_abc123",
        "created_at" => 1_702_256_327
      },
      %{
        "object" => "message.output.delta",
        "conversation_id" => "conv_abc123",
        "content" => "Hello! How can I "
      },
      %{
        "object" => "message.output.delta",
        "conversation_id" => "conv_abc123",
        "content" => "help you today?"
      },
      %{
        "object" => "conversation.response.done",
        "conversation_id" => "conv_abc123",
        "usage" => %{
          "prompt_tokens" => 10,
          "completion_tokens" => 12,
          "total_tokens" => 22
        }
      }
    ]
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
          :fim_completion => any(),
          :batch_job => any(),
          :batch_jobs => any(),
          :batch_job_cancelled => any(),
          :fine_tuning_job => any(),
          :fine_tuning_jobs => any(),
          :fine_tuning_job_detailed => any(),
          :fine_tuning_job_cancelled => any(),
          :fine_tuning_job_started => any(),
          :fine_tuning_job_dry_run => any(),
          :ft_model_updated => any(),
          :ft_model_archived => any(),
          :ft_model_unarchived => any(),
          :model_deleted => any(),
          :classification => any(),
          :classifications => any(),
          :moderation => any(),
          :moderations => any(),
          :agent => any(),
          :agents => any(),
          :agent_alias => any(),
          :agent_aliases => any(),
          :agent_completion => any(),
          :conversation_response => any(),
          :conversation_list => any(),
          :conversation => any(),
          :conversation_history => any(),
          :conversation_messages => any(),
          optional(any()) => any()
        }
  def get_mocks do
    Map.merge(@default_mocks, Process.get(@mocks_key, %{}))
  end

  @spec client(function(), keyword()) :: Mistral.client()
  def client(plug, opts \\ []) when is_function(plug, 1) do
    struct(Mistral, req: Req.new([plug: plug] ++ opts))
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

  @spec respond_empty(Plug.Conn.t()) :: Plug.Conn.t()
  def respond_empty(conn) do
    send_resp(conn, 204, "")
  end

  @spec respond_raw(Plug.Conn.t(), binary(), String.t()) :: Plug.Conn.t()
  def respond_raw(conn, body, content_type \\ "application/octet-stream") do
    conn
    |> put_resp_header("content-type", content_type)
    |> send_resp(200, body)
  end

  @spec respond_after_failures(
          Plug.Conn.t(),
          non_neg_integer(),
          atom() | non_neg_integer(),
          :counters.counters_ref()
        ) :: Plug.Conn.t()
  def respond_after_failures(conn, failures, success_response, counter) do
    count = :counters.get(counter, 1)
    :counters.add(counter, 1, 1)

    if count < failures do
      respond(conn, 500)
    else
      respond(conn, success_response)
    end
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
