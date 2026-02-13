# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added

- **Classification & Moderation API**: Added text and chat classification/moderation endpoints
  - `classify/2` - Classify text input via `/classifications`
  - `classify_chat/2` - Classify chat conversations via `/chat/classifications`
  - `moderate/2` - Moderate text input via `/moderations`
  - `moderate_chat/2` - Moderate chat conversations via `/chat/moderations`
- **FIM Completions API**: Added fill-in-the-middle code completion endpoint with streaming support
  - `fim/2` - Code completion via `/fim/completions` with prompt, optional suffix, and full streaming support (`stream: true` or `stream: pid`)
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
