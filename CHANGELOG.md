# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

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
