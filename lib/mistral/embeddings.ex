defmodule Mistral.Embeddings do
  @moduledoc """
  Utility functions for working with embedding vectors.

  Provides similarity calculations, distance metrics, batch processing,
  and helpers for extracting embeddings from `Mistral.embed/2` API responses.

  All core math functions operate on raw lists of numbers, keeping them
  composable and testable independently of the API.

  ## Examples

      # Compare two embeddings
      iex> a = [1.0, 0.0, 0.0]
      iex> b = [0.0, 1.0, 0.0]
      iex> Mistral.Embeddings.cosine_similarity(a, b)
      0.0

      # Find the most similar embedding from a list
      iex> target = [1.0, 0.0]
      iex> embeddings = [[1.0, 0.0], [0.0, 1.0], [0.7, 0.7]]
      iex> Mistral.Embeddings.most_similar(target, embeddings)
      {0, 1.0}

      # Extract embeddings from an API response
      iex> response = %{"data" => [%{"embedding" => [0.1, 0.2]}, %{"embedding" => [0.3, 0.4]}]}
      iex> Mistral.Embeddings.extract_embeddings(response)
      [[0.1, 0.2], [0.3, 0.4]]
  """

  @typedoc "A list of numbers representing an embedding vector."
  @type embedding() :: [number()]

  @doc """
  Computes the cosine similarity between two embedding vectors.

  Returns a float in the range `[-1, 1]`, where `1` means identical direction,
  `0` means orthogonal, and `-1` means opposite direction.

  Raises `ArgumentError` if the vectors have different lengths or if either
  vector is a zero vector.

  ## Examples

      iex> Mistral.Embeddings.cosine_similarity([1.0, 0.0], [1.0, 0.0])
      1.0

      iex> Mistral.Embeddings.cosine_similarity([1.0, 0.0], [0.0, 1.0])
      0.0
  """
  @spec cosine_similarity(embedding(), embedding()) :: float()
  def cosine_similarity(a, b) do
    validate_same_length!(a, b)

    {dot, norm_a, norm_b} = dot_and_norms(a, b)

    if norm_a == 0.0 or norm_b == 0.0 do
      raise ArgumentError, "cannot compute cosine similarity for zero vectors"
    end

    dot / (:math.sqrt(norm_a) * :math.sqrt(norm_b))
  end

  @doc """
  Computes the Euclidean distance between two embedding vectors.

  Returns a non-negative float. A distance of `0.0` means the vectors are identical.

  Raises `ArgumentError` if the vectors have different lengths.

  ## Examples

      iex> Mistral.Embeddings.euclidean_distance([0.0, 0.0], [3.0, 4.0])
      5.0

      iex> Mistral.Embeddings.euclidean_distance([1.0, 2.0], [1.0, 2.0])
      0.0
  """
  @spec euclidean_distance(embedding(), embedding()) :: float()
  def euclidean_distance(a, b) do
    validate_same_length!(a, b)

    a
    |> Enum.zip(b)
    |> Enum.reduce(0.0, fn {ai, bi}, acc ->
      diff = ai - bi
      acc + diff * diff
    end)
    |> :math.sqrt()
  end

  @doc """
  Computes cosine similarity between a target and a list of embeddings.

  Returns a list of `{index, score}` tuples sorted by score descending
  (most similar first).

  ## Examples

      iex> target = [1.0, 0.0]
      iex> embeddings = [[1.0, 0.0], [0.0, 1.0]]
      iex> Mistral.Embeddings.batch_cosine_similarity(target, embeddings)
      [{0, 1.0}, {1, 0.0}]
  """
  @spec batch_cosine_similarity(embedding(), [embedding()]) :: [{non_neg_integer(), float()}]
  def batch_cosine_similarity(target, embeddings) do
    embeddings
    |> Enum.with_index()
    |> Enum.map(fn {emb, idx} -> {idx, cosine_similarity(target, emb)} end)
    |> Enum.sort_by(fn {_idx, score} -> score end, :desc)
  end

  @doc """
  Computes Euclidean distance between a target and a list of embeddings.

  Returns a list of `{index, distance}` tuples sorted by distance ascending
  (closest first).

  ## Examples

      iex> target = [0.0, 0.0]
      iex> embeddings = [[3.0, 4.0], [1.0, 0.0]]
      iex> Mistral.Embeddings.batch_euclidean_distance(target, embeddings)
      [{1, 1.0}, {0, 5.0}]
  """
  @spec batch_euclidean_distance(embedding(), [embedding()]) :: [{non_neg_integer(), float()}]
  def batch_euclidean_distance(target, embeddings) do
    embeddings
    |> Enum.with_index()
    |> Enum.map(fn {emb, idx} -> {idx, euclidean_distance(target, emb)} end)
    |> Enum.sort_by(fn {_idx, dist} -> dist end, :asc)
  end

  @doc """
  Returns the single most similar embedding to the target.

  Returns a `{index, score_or_distance}` tuple.

  ## Options

    * `:metric` - `:cosine` (default) or `:euclidean`

  ## Examples

      iex> target = [1.0, 0.0]
      iex> embeddings = [[0.0, 1.0], [1.0, 0.0]]
      iex> Mistral.Embeddings.most_similar(target, embeddings)
      {1, 1.0}

      iex> target = [0.0, 0.0]
      iex> embeddings = [[3.0, 4.0], [1.0, 0.0]]
      iex> Mistral.Embeddings.most_similar(target, embeddings, metric: :euclidean)
      {1, 1.0}
  """
  @spec most_similar(embedding(), [embedding()], keyword()) :: {non_neg_integer(), float()}
  def most_similar(target, embeddings, opts \\ []) do
    rank_by_similarity(target, embeddings, opts) |> hd()
  end

  @doc """
  Returns the single least similar embedding to the target.

  Returns a `{index, score_or_distance}` tuple.

  ## Options

    * `:metric` - `:cosine` (default) or `:euclidean`

  ## Examples

      iex> target = [1.0, 0.0]
      iex> embeddings = [[0.0, 1.0], [1.0, 0.0]]
      iex> Mistral.Embeddings.least_similar(target, embeddings)
      {0, 0.0}

      iex> target = [0.0, 0.0]
      iex> embeddings = [[3.0, 4.0], [1.0, 0.0]]
      iex> Mistral.Embeddings.least_similar(target, embeddings, metric: :euclidean)
      {0, 5.0}
  """
  @spec least_similar(embedding(), [embedding()], keyword()) :: {non_neg_integer(), float()}
  def least_similar(target, embeddings, opts \\ []) do
    rank_by_similarity(target, embeddings, opts) |> List.last()
  end

  @doc """
  Ranks all embeddings by similarity to the target.

  Returns a list of `{index, score_or_distance}` tuples, ordered from most
  similar to least similar.

  ## Options

    * `:metric` - `:cosine` (default) or `:euclidean`
    * `:top_k` - optional integer to limit the number of results

  ## Examples

      iex> target = [1.0, 0.0]
      iex> embeddings = [[1.0, 0.0], [0.7, 0.7], [0.0, 1.0]]
      iex> Mistral.Embeddings.rank_by_similarity(target, embeddings, top_k: 2)
      [{0, 1.0}, {1, _score}]
  """
  @spec rank_by_similarity(embedding(), [embedding()], keyword()) ::
          [{non_neg_integer(), float()}]
  def rank_by_similarity(target, embeddings, opts \\ []) do
    metric = Keyword.get(opts, :metric, :cosine)
    top_k = Keyword.get(opts, :top_k)

    ranked =
      case metric do
        :cosine -> batch_cosine_similarity(target, embeddings)
        :euclidean -> batch_euclidean_distance(target, embeddings)
      end

    if top_k, do: Enum.take(ranked, top_k), else: ranked
  end

  @doc """
  Extracts raw embedding vectors from a `Mistral.embed/2` response.

  Returns a list of lists of floats.

  ## Examples

      iex> response = %{"data" => [%{"embedding" => [0.1, 0.2]}, %{"embedding" => [0.3, 0.4]}]}
      iex> Mistral.Embeddings.extract_embeddings(response)
      [[0.1, 0.2], [0.3, 0.4]]
  """
  @spec extract_embeddings(map()) :: [embedding()]
  def extract_embeddings(%{"data" => data}) do
    Enum.map(data, fn %{"embedding" => embedding} -> embedding end)
  end

  @doc """
  Extracts a single embedding vector at the given index from a `Mistral.embed/2` response.

  ## Examples

      iex> response = %{"data" => [%{"embedding" => [0.1, 0.2]}, %{"embedding" => [0.3, 0.4]}]}
      iex> Mistral.Embeddings.extract_embedding(response, 0)
      [0.1, 0.2]

      iex> response = %{"data" => [%{"embedding" => [0.1, 0.2]}, %{"embedding" => [0.3, 0.4]}]}
      iex> Mistral.Embeddings.extract_embedding(response, 1)
      [0.3, 0.4]
  """
  @spec extract_embedding(map(), non_neg_integer()) :: embedding()
  def extract_embedding(%{"data" => data}, index \\ 0) do
    data |> Enum.at(index) |> Map.fetch!("embedding")
  end

  # -- Private helpers --

  defp validate_same_length!(a, b) do
    len_a = length(a)
    len_b = length(b)

    if len_a != len_b do
      raise ArgumentError,
            "vectors must have the same length, got #{len_a} and #{len_b}"
    end
  end

  defp dot_and_norms(a, b) do
    Enum.zip(a, b)
    |> Enum.reduce({0.0, 0.0, 0.0}, fn {ai, bi}, {dot, norm_a, norm_b} ->
      {dot + ai * bi, norm_a + ai * ai, norm_b + bi * bi}
    end)
  end
end
