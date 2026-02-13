# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added

- **Conversations API**: Added managed conversation state with multi-turn handling, history retrieval, and streaming support
  - `create_conversation/2` - Create a new conversation with string or entry list inputs via `/conversations` with full streaming support (`stream: true` or `stream: pid`)
  - `list_conversations/2` - List conversations with pagination (`page`, `page_size`)
  - `get_conversation/2` - Retrieve a conversation by ID
  - `delete_conversation/2` - Delete a conversation by ID
  - `append_conversation/3` - Append entries to an existing conversation via POST `/conversations/{id}` with full streaming support
  - `get_conversation_history/2` - Retrieve conversation history (input/output entries) via `/conversations/{id}/history`
  - `get_conversation_messages/2` - Retrieve conversation messages via `/conversations/{id}/messages`
  - `restart_conversation/3` - Restart a conversation from a specific entry via `/conversations/{id}/restart` with full streaming support
- **Agents API**: Added full CRUD operations for agents, versioning, aliases, and agent completions with streaming support
  - `create_agent/2` - Create an agent with model, name, instructions, tools, and completion args via `/agents`
  - `list_agents/2` - List agents with filtering (`name`, `id`, `sources`, `deployment_chat`) and pagination (`page`, `page_size`)
  - `get_agent/3` - Retrieve an agent by ID with optional version selection (`agent_version`)
  - `update_agent/3` - Update an agent (creates a new version) via PATCH `/agents/{agent_id}`
  - `delete_agent/2` - Delete an agent by ID
  - `update_agent_version/3` - Switch an agent to a specific version via PATCH `/agents/{agent_id}/version`
  - `list_agent_versions/3` - List all versions of an agent with pagination
  - `get_agent_version/3` - Get a specific version of an agent
  - `create_or_update_agent_alias/4` - Create or update a version alias for an agent via PUT `/agents/{agent_id}/aliases`
  - `list_agent_aliases/2` - List all version aliases for an agent
  - `agent_completion/2` - Agent completions via `/agents/completions` with full streaming support (`stream: true` or `stream: pid`)
- **Classification & Moderation API**: Added text and chat classification/moderation endpoints
  - `classify/2` - Classify text input via `/classifications`
  - `classify_chat/2` - Classify chat conversations via `/chat/classifications`
  - `moderate/2` - Moderate text input via `/moderations`
  - `moderate_chat/2` - Moderate chat conversations via `/chat/moderations`
- **Batch API**: Added batch job endpoints for asynchronous batch inference
  - `create_batch_job/2` - Create a batch job with input files or inline requests via `/batch/jobs`
  - `list_batch_jobs/2` - List batch jobs with filtering (`model`, `status`, `created_after`, `created_by_me`) and pagination (`page`, `page_size`)
  - `get_batch_job/3` - Retrieve a batch job by ID with optional inline results
  - `cancel_batch_job/2` - Cancel a batch job by ID
- **FIM Completions API**: Added fill-in-the-middle code completion endpoint with streaming support
  - `fim/2` - Code completion via `/fim/completions` with prompt, optional suffix, and full streaming support (`stream: true` or `stream: pid`)
- **Fine-tuning API**: Added fine-tuning job and model management endpoints
  - `create_fine_tuning_job/2` - Create a fine-tuning job with training files, hyperparameters, W&B integrations, and dry run support via `/fine_tuning/jobs`
  - `list_fine_tuning_jobs/2` - List fine-tuning jobs with filtering (`model`, `status`, `suffix`, `wandb_project`, `created_after`, `created_before`, `created_by_me`) and pagination (`page`, `page_size`)
  - `get_fine_tuning_job/2` - Retrieve a fine-tuning job by ID
  - `cancel_fine_tuning_job/2` - Cancel a fine-tuning job by ID
  - `start_fine_tuning_job/2` - Start a fine-tuning job by ID
  - `update_fine_tuned_model/3` - Update a fine-tuned model's name and description via PATCH `/fine_tuning/models/{model_id}`
  - `archive_fine_tuned_model/2` - Archive a fine-tuned model
  - `unarchive_fine_tuned_model/2` - Unarchive a fine-tuned model
  - `delete_model/2` - Delete a model by ID
- **Complete File Operations**: Added missing file management endpoints to complete the file lifecycle
  - `list_files/2` - List uploaded files with filtering (`purpose`, `source`, `sample_type`, `search`) and pagination (`page`, `page_size`)
  - `delete_file/2` - Delete a file by ID
  - `download_file/2` - Download raw file content by ID

## [0.4.0] - 2025-07-20

### Added

- **Response Format Control**: Support for JSON mode and structured output with schema validation
  - `response_format` parameter for `chat/2` with support for `json_object` and `json_schema` types
  - JSON Schema validation with custom schemas for structured responses
  - OCR annotation formats: `bbox_annotation_format` and `document_annotation_format` for structured OCR output
  - Comprehensive validation ensuring `json_schema` is provided when type is `json_schema`

## [0.3.0] - 2025-03-13

### Changed

- Removed `Mistral.Models` module.
  - Replaced `Mistral.Models.list/1` with `Mistral.list_models/1`
  - Replaced `Mistral.Models.get/2` with `Mistral.get_model/2`

### Breaking Changes

- **Removed `Mistral.Models` module**: This change consolidates model-related API methods (`list_models/1` and `get_model/2`) into the main `Mistral` module.
- **Migration guide:** Update calls from `Mistral.Models.list/1` → `Mistral.list_models/1`, and `Mistral.Models.get/2` → `Mistral.get_model/2`.

### Added

- Add `Mistral.Models` module for working with Mistral's models API
  - `list/1` - List all available models
  - `get/2` - Retrieve information about a specific model
- Support Mistral API file endpoints
  - `upload_file/3` function for uploading files to the Mistral API with support for OCR, fine-tuning, and batch processing purposes.
  - `get_file/2` to retrieve file details.
  - `get_file_url/2` to obtain a signed URL for a file with optional `expiry` parameter validation.
- **OCR API Support:**
  - Introduced `Mistral.ocr/2` to process document and image OCR via `/v1/ocr`.
  - Added `ocr_opts` validation schema for structured request validation.

## [0.2.0] - 2025-03-13

### Added

- Add dedicated `Mistral.Schemas` module for schema validation
- Add `Mistral.APIError` module for better error handling

### Changed

- Update API schema validation to match Mistral's API specification

## [0.1.0] - 2025-03-12

### Added

- Initial release with support for:
  - Chat completions
  - Function calling/tool use
  - Embeddings
  - Streaming responses
  - Basic error handling
