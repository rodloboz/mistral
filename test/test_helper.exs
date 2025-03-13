ExUnit.start()

if System.get_env("TEST_INTEGRATION") do
  Application.put_env(:mistral, :api_key, "test_key")

  {:ok, _} =
    Bandit.start_link(
      plug: Mistral.MockServer,
      port: 4001,
      startup_log: false
    )

  Application.put_env(:mistral, :api_url, "http://localhost:4001")
end
