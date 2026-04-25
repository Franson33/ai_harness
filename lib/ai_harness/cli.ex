defmodule AiHarness.CLI do
  alias AiHarness.Commands
  alias AiHarness.Config
  alias AiHarness.OllamaClient
  alias AiHarness.Session

  def start() do
    Config.welcome_message()
    |> IO.puts()

    Session.new()
    |> loop()

    :ok
  end

  defp loop(session) do
    session
    |> read_input()
    |> handle_read_result(session)
  end

  defp read_input(_session) do
    Config.prompt()
    |> IO.gets()
  end

  defp handle_read_result(:eof, _session) do
    IO.puts("Goodbye!")
    :ok
  end

  defp handle_read_result({:error, reason}, session) do
    IO.puts("Input error: #{inspect(reason)}")
    loop(session)
  end

  defp handle_read_result(input, session) when is_binary(input) do
    input
    |> String.trim()
    |> handle_input(session)
    |> handle_action()
  end

  defp handle_input("", session) do
    {:continue, session}
  end

  defp handle_input("/" <> _ = command, session) do
    Commands.handle(command, session)
  end

  defp handle_input(message, session) do
    new_session = Session.add_user_message(session, message)

    response =
      new_session
      |> Session.messages()
      |> OllamaClient.chat()

    build_chat_action(response, session, new_session)
  end

  defp build_chat_action({:ok, response}, _session, new_session) do
    new_session
    |> Session.add_assistant_message(response)
    |> then(&{:continue, &1, response})
  end

  defp build_chat_action({:error, reason}, session, _new_session) do
    {:continue, session, "Error: #{reason}"}
  end

  defp handle_action({:exit, _session}) do
    IO.puts("Goodbye!")
    :ok
  end

  defp handle_action({:continue, session}) do
    loop(session)
  end

  defp handle_action({:continue, session, output}) do
    IO.puts(output)

    loop(session)
  end

  defp handle_action({:clear, session, output}) do
    IO.puts(output)

    loop(session)
  end
end
