defmodule Mistral.Retry do
  @moduledoc """
  Retry configuration for Mistral API requests.

  Provides a delay function implementing exponential backoff with full jitter,
  designed for use with `Req`'s built-in retry system.

  ## Delay formula

      random(0, min(cap, base * 2^attempt))

  - Base delay: 1,000ms
  - Maximum delay cap: 60,000ms (60 seconds)
  - Full jitter spreads retry attempts to avoid thundering herd effects

  ## Default retry behavior

  By default, the Mistral client uses `retry: :transient`, which retries on:
  - HTTP 408, 429, and 5xx status codes
  - Socket errors and connection resets

  Streaming requests have retry disabled since SSE streams cannot be safely replayed.
  """

  @max_delay 60_000

  @doc """
  Calculates retry delay using exponential backoff with full jitter.

  Returns a random delay between 0 and `min(60_000, 2^retry_count * 1000)` milliseconds.

  ## Examples

      iex> delay = Mistral.Retry.delay(0)
      iex> delay >= 0 and delay <= 1000
      true

      iex> delay = Mistral.Retry.delay(2)
      iex> delay >= 0 and delay <= 4000
      true

  """
  @spec delay(non_neg_integer()) :: non_neg_integer()
  def delay(retry_count) do
    max = min(@max_delay, Integer.pow(2, retry_count) * 1000)
    :rand.uniform(max + 1) - 1
  end
end
