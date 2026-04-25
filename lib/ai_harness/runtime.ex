defmodule AiHarness.Runtime do
  alias AiHarness.Session
  alias AiHarness.Commands
  alias AiHarness.OllamaClient

  defstruct session: Session.new()

  def new() do
    %__MODULE__{}
  end

  def handle_input(runtime, input) when is_binary(input) do
    input
    |> String.trim()
    |> handle_trimmed_input(runtime)
  end

  defp handle_trimmed_input("", runtime) do
    {:continue, runtime}
  end

  defp handle_trimmed_input("/" <> _rest = trimmed, runtime) do
    handle_command(runtime, trimmed)
  end

  defp handle_trimmed_input(trimmed, runtime) do
    handle_chat(runtime, trimmed)
  end

  defp handle_command(%__MODULE__{session: session} = runtime, command) do
    command
    |> Commands.handle(session)
    |> handle_command_result(runtime)
  end

  defp handle_chat(%__MODULE__{session: session} = runtime, message) do
    pending_session = Session.add_user_message(session, message)

    result =
      pending_session
      |> Session.messages()
      |> OllamaClient.chat()

    handle_chat_result(result, runtime, pending_session)
  end

  defp handle_command_result({:exit, new_session}, runtime) do
    {:exit, %{runtime | session: new_session}}
  end

  defp handle_command_result({:continue, new_session, output}, runtime) do
    {:continue, %{runtime | session: new_session}, output}
  end

  defp handle_chat_result({:ok, response}, runtime, pending_session) do
    pending_session
    |> Session.add_assistant_message(response)
    |> then(&{:continue, %{runtime | session: &1}, response})
  end

  defp handle_chat_result({:error, reason}, runtime, _pending_session) do
    {:continue, runtime, "Error: #{reason}"}
  end
end
