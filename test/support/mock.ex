defmodule Mistral.Mock do
  alias Plug.Conn.Status
  import Plug.Conn

  @mocks %{
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
    }
  }

  @spec client(function()) :: Mistral.client()
  def client(plug) when is_function(plug, 1) do
    struct(Mistral, req: Req.new(plug: plug))
  end

  @spec respond(Plug.Conn.t(), atom() | number()) :: Plug.Conn.t()
  def respond(conn, name) when is_atom(name) do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, Jason.encode!(@mocks[name]))
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
end
