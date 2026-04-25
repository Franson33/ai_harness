defmodule AiHarness.SessionTest do
  use ExUnit.Case, async: true

  alias AiHarness.Session

  test "new/0 returns an empty session" do
    session = Session.new()

    assert Session.messages(session) == []
    assert Session.history_lines(session) == ["No messages yet."]
  end

  test "add_user_message/2 appends a trimmed user message" do
    session =
      Session.new()
      |> Session.add_user_message("  hello  ")

    assert Session.messages(session) == [
             %{"role" => "user", "content" => "hello"}
           ]
  end

  test "add_assistant_message/2 appends an assistant message" do
    session =
      Session.new()
      |> Session.add_assistant_message("Hi there")

    assert Session.messages(session) == [
             %{"role" => "assistant", "content" => "Hi there"}
           ]
  end

  test "clear/1 removes all messages" do
    session =
      Session.new()
      |> Session.add_user_message("hello")
      |> Session.add_assistant_message("hi")
      |> Session.clear()

    assert Session.messages(session) == []
    assert Session.history_lines(session) == ["No messages yet."]
  end

  test "history_lines/1 formats message history" do
    session =
      Session.new()
      |> Session.add_user_message("hello")
      |> Session.add_assistant_message("hi")

    assert Session.history_lines(session) == [
             "user: hello",
             "assistant: hi"
           ]
  end
end
