defmodule AiHarness.OllamaClient do
  alias AiHarness.Config
  alias Req.Response
  alias AiHarness.DebugLogger

  def chat(messages) when is_list(messages) do
    url = Config.ollama_base_url() <> "/api/chat"

    body = %{
      model: Config.model(),
      messages: messages,
      stream: false
    }

    DebugLogger.log_request(messages)

    Req.post(
      url,
      json: body,
      receive_timeout: Config.ollama_receive_timeout()
    )
    |> handle_response()
  end

  defp handle_response(
         {:ok, %Response{status: 200, body: %{"message" => %{"content" => content}}}}
       ) do
    DebugLogger.log_response(content)

    {:ok, content}
  end

  defp handle_response({:ok, %Response{status: status, body: body}}) do
    {:error, "Unexpected response status #{status}: #{inspect(body)}"}
  end

  defp handle_response({:error, exception}) do
    {:error, Exception.message(exception)}
  end
end
