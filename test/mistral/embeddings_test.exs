defmodule Mistral.EmbeddingsTest do
  use ExUnit.Case, async: true

  alias Mistral.Embeddings

  describe "cosine_similarity/2" do
    test "identical vectors return 1.0" do
      assert_in_delta Embeddings.cosine_similarity([1.0, 0.0, 0.0], [1.0, 0.0, 0.0]), 1.0, 1.0e-10
    end

    test "orthogonal vectors return 0.0" do
      assert_in_delta Embeddings.cosine_similarity([1.0, 0.0], [0.0, 1.0]), 0.0, 1.0e-10
    end

    test "opposite vectors return -1.0" do
      assert_in_delta Embeddings.cosine_similarity([1.0, 0.0], [-1.0, 0.0]), -1.0, 1.0e-10
    end

    test "non-unit vectors" do
      # [3, 4] and [4, 3]: dot = 24, |a| = 5, |b| = 5, cosine = 24/25
      assert_in_delta Embeddings.cosine_similarity([3.0, 4.0], [4.0, 3.0]), 24.0 / 25.0, 1.0e-10
    end

    test "raises on mismatched lengths" do
      assert_raise ArgumentError, ~r/same length/, fn ->
        Embeddings.cosine_similarity([1.0, 0.0], [1.0, 0.0, 0.0])
      end
    end

    test "raises on zero vector" do
      assert_raise ArgumentError, ~r/zero vectors/, fn ->
        Embeddings.cosine_similarity([0.0, 0.0], [1.0, 0.0])
      end

      assert_raise ArgumentError, ~r/zero vectors/, fn ->
        Embeddings.cosine_similarity([1.0, 0.0], [0.0, 0.0])
      end
    end
  end

  describe "euclidean_distance/2" do
    test "same vector returns 0.0" do
      assert_in_delta Embeddings.euclidean_distance([1.0, 2.0, 3.0], [1.0, 2.0, 3.0]),
                      0.0,
                      1.0e-10
    end

    test "known distance (3-4-5 triangle)" do
      assert_in_delta Embeddings.euclidean_distance([0.0, 0.0], [3.0, 4.0]), 5.0, 1.0e-10
    end

    test "unit distance" do
      assert_in_delta Embeddings.euclidean_distance([0.0], [1.0]), 1.0, 1.0e-10
    end

    test "raises on mismatched lengths" do
      assert_raise ArgumentError, ~r/same length/, fn ->
        Embeddings.euclidean_distance([1.0, 0.0], [1.0])
      end
    end
  end

  describe "batch_cosine_similarity/2" do
    test "returns results sorted by score descending" do
      target = [1.0, 0.0]

      embeddings = [
        [0.0, 1.0],
        [1.0, 0.0],
        [1.0, 1.0]
      ]

      result = Embeddings.batch_cosine_similarity(target, embeddings)

      assert [{1, score1}, {2, score2}, {0, score3}] = result
      assert_in_delta score1, 1.0, 1.0e-10
      assert_in_delta score2, :math.sqrt(2) / 2, 1.0e-10
      assert_in_delta score3, 0.0, 1.0e-10
    end

    test "handles single embedding" do
      assert [{0, score}] = Embeddings.batch_cosine_similarity([1.0, 0.0], [[1.0, 0.0]])
      assert_in_delta score, 1.0, 1.0e-10
    end
  end

  describe "batch_euclidean_distance/2" do
    test "returns results sorted by distance ascending" do
      target = [0.0, 0.0]

      embeddings = [
        [3.0, 4.0],
        [1.0, 0.0],
        [0.0, 2.0]
      ]

      result = Embeddings.batch_euclidean_distance(target, embeddings)

      assert [{1, dist1}, {2, dist2}, {0, dist3}] = result
      assert_in_delta dist1, 1.0, 1.0e-10
      assert_in_delta dist2, 2.0, 1.0e-10
      assert_in_delta dist3, 5.0, 1.0e-10
    end
  end

  describe "most_similar/3" do
    test "returns the most similar with cosine (default)" do
      target = [1.0, 0.0]
      embeddings = [[0.0, 1.0], [1.0, 0.0], [0.5, 0.5]]

      assert {1, score} = Embeddings.most_similar(target, embeddings)
      assert_in_delta score, 1.0, 1.0e-10
    end

    test "returns the closest with euclidean metric" do
      target = [0.0, 0.0]
      embeddings = [[3.0, 4.0], [1.0, 0.0], [0.0, 2.0]]

      assert {1, dist} = Embeddings.most_similar(target, embeddings, metric: :euclidean)
      assert_in_delta dist, 1.0, 1.0e-10
    end
  end

  describe "least_similar/3" do
    test "returns the least similar with cosine (default)" do
      target = [1.0, 0.0]
      embeddings = [[0.0, 1.0], [1.0, 0.0], [0.5, 0.5]]

      assert {0, score} = Embeddings.least_similar(target, embeddings)
      assert_in_delta score, 0.0, 1.0e-10
    end

    test "returns the farthest with euclidean metric" do
      target = [0.0, 0.0]
      embeddings = [[3.0, 4.0], [1.0, 0.0], [0.0, 2.0]]

      assert {0, dist} = Embeddings.least_similar(target, embeddings, metric: :euclidean)
      assert_in_delta dist, 5.0, 1.0e-10
    end
  end

  describe "rank_by_similarity/3" do
    test "returns full ranking by cosine similarity" do
      target = [1.0, 0.0]

      embeddings = [
        [0.0, 1.0],
        [1.0, 0.0],
        [1.0, 1.0]
      ]

      result = Embeddings.rank_by_similarity(target, embeddings)

      assert length(result) == 3
      assert [{1, _}, {2, _}, {0, _}] = result
    end

    test "respects top_k option" do
      target = [1.0, 0.0]

      embeddings = [
        [0.0, 1.0],
        [1.0, 0.0],
        [1.0, 1.0]
      ]

      result = Embeddings.rank_by_similarity(target, embeddings, top_k: 2)

      assert length(result) == 2
      assert [{1, _}, {2, _}] = result
    end

    test "supports euclidean metric" do
      target = [0.0, 0.0]
      embeddings = [[3.0, 4.0], [1.0, 0.0]]

      result = Embeddings.rank_by_similarity(target, embeddings, metric: :euclidean)

      assert [{1, dist1}, {0, dist2}] = result
      assert_in_delta dist1, 1.0, 1.0e-10
      assert_in_delta dist2, 5.0, 1.0e-10
    end

    test "top_k with euclidean metric" do
      target = [0.0, 0.0]
      embeddings = [[3.0, 4.0], [1.0, 0.0], [0.0, 2.0]]

      result = Embeddings.rank_by_similarity(target, embeddings, metric: :euclidean, top_k: 1)

      assert [{1, dist}] = result
      assert_in_delta dist, 1.0, 1.0e-10
    end
  end

  describe "extract_embeddings/1" do
    test "extracts all embeddings from API response" do
      response = %{
        "id" => "embd-abc123",
        "object" => "list",
        "data" => [
          %{"object" => "embedding", "embedding" => [0.1, 0.2, 0.3], "index" => 0},
          %{"object" => "embedding", "embedding" => [0.4, 0.5, 0.6], "index" => 1}
        ],
        "model" => "mistral-embed",
        "usage" => %{"prompt_tokens" => 10, "total_tokens" => 10}
      }

      assert [[0.1, 0.2, 0.3], [0.4, 0.5, 0.6]] = Embeddings.extract_embeddings(response)
    end

    test "returns empty list for empty data" do
      assert [] = Embeddings.extract_embeddings(%{"data" => []})
    end
  end

  describe "extract_embedding/2" do
    test "extracts single embedding at default index 0" do
      response = %{
        "data" => [
          %{"embedding" => [0.1, 0.2, 0.3]},
          %{"embedding" => [0.4, 0.5, 0.6]}
        ]
      }

      assert [0.1, 0.2, 0.3] = Embeddings.extract_embedding(response)
    end

    test "extracts embedding at specified index" do
      response = %{
        "data" => [
          %{"embedding" => [0.1, 0.2, 0.3]},
          %{"embedding" => [0.4, 0.5, 0.6]}
        ]
      }

      assert [0.4, 0.5, 0.6] = Embeddings.extract_embedding(response, 1)
    end
  end
end
