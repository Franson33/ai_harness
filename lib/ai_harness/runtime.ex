defmodule AiHarness.Runtime do
  alias AiHarness.Session
  alias AiHarness.Commands
  alias AiHarness.OllamaClient

  defstruct session: Session.new()

  def new() do
    %__MODULE__{}
  end

  def handle_input(runtime, input) when is_binary(input) do
    trimmed = String.trim(input)

    cond do
      trimmed == "" ->
        {:continue, runtime}

      String.starts_with?(trimmed, "/") ->
        handle_command(runtime, trimmed)

      true ->
        handle_chat(runtime, trimmed)
    end
  end

  defp handle_command(%__MODULE__{session: session} = runtime, command) do
    case Commands.handle(command, session) do
      {:continue, new_session, output} ->
        {:continue, %{runtime | session: new_session}, output}

      {:exit, new_session} ->
        {:exit, %{runtime | session: new_session}}
    end
  end

  defp handle_chat(%__MODULE__{session: session} = runtime, message) do
    pending_session = Session.add_user_message(session, message)

    case OllamaClient.chat(Session.messages(pending_session)) do
      {:ok, response} ->
        new_session = Session.add_assistant_message(pending_session, response)

        {:continue, %{runtime | session: new_session}, response}

      {:error, reason} ->
        {:continue, runtime, "Error: #{reason}"}
    end
  end
end
