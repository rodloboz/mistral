defmodule Mistral.RetryTest do
  use ExUnit.Case, async: true

  alias Mistral.{Mock, Retry}

  describe "Mistral.Retry.delay/1" do
    test "returns values within expected range for retry 0" do
      for _ <- 1..50 do
        delay = Retry.delay(0)
        assert delay >= 0 and delay <= 1_000
      end
    end

    test "returns values within expected range for retry 1" do
      for _ <- 1..50 do
        delay = Retry.delay(1)
        assert delay >= 0 and delay <= 2_000
      end
    end

    test "returns values within expected range for retry 2" do
      for _ <- 1..50 do
        delay = Retry.delay(2)
        assert delay >= 0 and delay <= 4_000
      end
    end

    test "respects 60-second cap for large retry counts" do
      for _ <- 1..50 do
        delay = Retry.delay(20)
        assert delay >= 0 and delay <= 60_000
      end
    end

    test "produces varying values (jitter works)" do
      delays = for _ <- 1..100, do: Retry.delay(3)
      unique = Enum.uniq(delays)
      assert length(unique) > 1
    end
  end

  describe "retry integration" do
    defp retry_opts do
      [
        retry: :transient,
        retry_delay: fn _ -> 0 end,
        max_retries: 3,
        retry_log_level: false
      ]
    end

    test "retries on 500 and succeeds" do
      counter = :counters.new(1, [:atomics])

      client =
        Mock.client(
          fn conn ->
            Mock.respond_after_failures(conn, 2, :chat_completion, counter)
          end,
          retry_opts()
        )

      assert {:ok, %{"choices" => _}} =
               Mistral.chat(client,
                 model: "mistral-small-latest",
                 messages: [%{role: "user", content: "Hello"}]
               )

      assert :counters.get(counter, 1) == 3
    end

    test "retries on 429 and succeeds" do
      counter = :counters.new(1, [:atomics])

      client =
        Mock.client(
          fn conn ->
            count = :counters.get(counter, 1)
            :counters.add(counter, 1, 1)

            if count < 1 do
              Mock.respond(conn, 429)
            else
              Mock.respond(conn, :chat_completion)
            end
          end,
          retry_opts()
        )

      assert {:ok, %{"choices" => _}} =
               Mistral.chat(client,
                 model: "mistral-small-latest",
                 messages: [%{role: "user", content: "Hello"}]
               )

      assert :counters.get(counter, 1) == 2
    end

    test "retries on 503 and succeeds" do
      counter = :counters.new(1, [:atomics])

      client =
        Mock.client(
          fn conn ->
            count = :counters.get(counter, 1)
            :counters.add(counter, 1, 1)

            if count < 1 do
              Mock.respond(conn, 503)
            else
              Mock.respond(conn, :chat_completion)
            end
          end,
          retry_opts()
        )

      assert {:ok, %{"choices" => _}} =
               Mistral.chat(client,
                 model: "mistral-small-latest",
                 messages: [%{role: "user", content: "Hello"}]
               )

      assert :counters.get(counter, 1) == 2
    end

    test "returns error after max retries exhausted" do
      counter = :counters.new(1, [:atomics])

      client =
        Mock.client(
          fn conn ->
            :counters.add(counter, 1, 1)
            Mock.respond(conn, 500)
          end,
          retry_opts()
        )

      assert {:error, %Mistral.APIError{status: 500}} =
               Mistral.chat(client,
                 model: "mistral-small-latest",
                 messages: [%{role: "user", content: "Hello"}]
               )

      # 1 initial + 3 retries = 4 total
      assert :counters.get(counter, 1) == 4
    end

    test "does not retry on 422" do
      counter = :counters.new(1, [:atomics])

      client =
        Mock.client(
          fn conn ->
            :counters.add(counter, 1, 1)
            Mock.respond(conn, 422)
          end,
          retry_opts()
        )

      assert {:error, %Mistral.APIError{}} =
               Mistral.chat(client,
                 model: "mistral-small-latest",
                 messages: [%{role: "user", content: "Hello"}]
               )

      assert :counters.get(counter, 1) == 1
    end

    test "does not retry on 401" do
      counter = :counters.new(1, [:atomics])

      client =
        Mock.client(
          fn conn ->
            :counters.add(counter, 1, 1)
            Mock.respond(conn, 401)
          end,
          retry_opts()
        )

      assert {:error, %Mistral.APIError{}} =
               Mistral.chat(client,
                 model: "mistral-small-latest",
                 messages: [%{role: "user", content: "Hello"}]
               )

      assert :counters.get(counter, 1) == 1
    end

    test "retry disabled with retry: false" do
      counter = :counters.new(1, [:atomics])

      client =
        Mock.client(
          fn conn ->
            Mock.respond_after_failures(conn, 1, :chat_completion, counter)
          end,
          retry: false
        )

      assert {:error, %Mistral.APIError{status: 500}} =
               Mistral.chat(client,
                 model: "mistral-small-latest",
                 messages: [%{role: "user", content: "Hello"}]
               )

      assert :counters.get(counter, 1) == 1
    end
  end
end
