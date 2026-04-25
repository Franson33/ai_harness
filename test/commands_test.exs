defmodule AiHarness.CommandsTest do
  use ExUnit.Case, async: true

  alias AiHarness.Commands
  alias AiHarness.Session

  test "/exit returns exit action" do
    session = Session.new()

    assert Commands.handle("/exit", session) == {:exit, session}
  end

  test "/clear clears history and returns a message" do
    session =
      Session.new()
      |> Session.add_user_message("hello")

    assert Commands.handle("/clear", session) ==
             {:clear, Session.new(), "History cleared."}
  end

  test "/history returns formatted history" do
    session =
      Session.new()
      |> Session.add_user_message("hello")
      |> Session.add_assistant_message("hi")

    assert Commands.handle("/history", session) ==
             {:continue, session, "user: hello\nassistant: hi"}
  end

  test "/history on empty session returns empty-state text" do
    session = Session.new()

    assert Commands.handle("/history", session) ==
             {:continue, session, "No messages yet."}
  end

  test "/help returns help text" do
    session = Session.new()

    assert Commands.handle("/help", session) ==
             {:continue, session,
              String.trim("""
              Available commands:
              /help
              /history
              /clear
              /exit
              """)}
  end

  test "unknown command returns fallback message" do
    session = Session.new()

    assert Commands.handle("/wat", session) ==
             {:continue, session,
              "I didn't understand that command. Type /help from available commands."}
  end
end
