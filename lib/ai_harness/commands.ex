defmodule AiHarness.Commands do
  alias AiHarness.Session

  @help_message """
  Available commands:
  /help
  /history
  /clear
  /exit
  """

  def handle("/exit", session) do
    {:exit, session}
  end

  def handle("/clear", session) do
    {:clear, Session.clear(session), "History cleared."}
  end

  def handle("/history", session) do
    output =
      Session.history_lines(session)
      |> Enum.join("\n")

    {:continue, session, output}
  end

  def handle("/help", session) do
    {:continue, session, String.trim(@help_message)}
  end

  def handle(_, session) do
    {:continue, session, "I didn't understand that command. Type /help from available commands."}
  end
end
