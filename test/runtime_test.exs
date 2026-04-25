defmodule AiHarness.RuntimeTest do
  use ExUnit.Case, async: true

  alias AiHarness.Runtime
  alias AiHarness.Session

  defmodule SuccessChatClient do
    def chat(_messages), do: {:ok, ~s({"type":"final","content":"stub response"})}
  end

  defmodule ErrorChatClient do
    def chat(_messages), do: {:error, "timeout"}
  end

  defmodule InvalidJsonChatClient do
    def chat(_messages), do: {:ok, "stub response"}
  end

  defmodule InvalidSchemaChatClient do
    def chat(_messages), do: {:ok, ~s({"foo":"bar"})}
  end

  test "new/0 starts with an empty session" do
    runtime = Runtime.new()

    assert runtime.session == Session.new()
  end

  test "handle_input/2 ignores blank input" do
    runtime = Runtime.new()

    assert Runtime.handle_input(runtime, "   ") == {:continue, runtime}
  end

  test "handle_input/2 routes help command through command handling" do
    runtime = Runtime.new()

    assert Runtime.handle_input(runtime, "/help") ==
             {:continue, runtime,
              String.trim("""
              Available commands:
              /help
              /history
              /clear
              /exit
              """)}
  end

  test "handle_input/2 clears session via command handling" do
    runtime = %Runtime{
      session:
        Session.new()
        |> Session.add_user_message("hello")
        |> Session.add_assistant_message("hi")
    }

    assert Runtime.handle_input(runtime, "/clear") ==
             {:continue, Runtime.new(), "History cleared."}
  end

  test "handle_input/2 exits via command handling" do
    runtime = Runtime.new()

    assert Runtime.handle_input(runtime, "/exit") == {:exit, runtime}
  end

  test "handle_input/2 appends user and assistant messages on successful chat" do
    runtime = %Runtime{chat_client: SuccessChatClient}

    assert Runtime.handle_input(runtime, "hello") ==
             {:continue,
              %Runtime{
                session: %Session{
                  messages: [
                    %{"role" => "user", "content" => "hello"},
                    %{"role" => "assistant", "content" => "stub response"}
                  ]
                },
                chat_client: SuccessChatClient
              }, "stub response"}
  end

  test "handle_input/2 keeps the session unchanged on chat error" do
    runtime = %Runtime{chat_client: ErrorChatClient}

    assert Runtime.handle_input(runtime, "hello") ==
             {:continue, runtime, "Error: timeout"}
  end

  test "handle_input/2 returns a parser error when the model response is not valid json" do
    runtime = %Runtime{chat_client: InvalidJsonChatClient}

    assert Runtime.handle_input(runtime, "hello") ==
             {:continue, runtime, "Error: unexpected byte at position 0: 0x73 (\"s\")"}
  end

  test "handle_input/2 returns a parser error when the model response json has invalid schema" do
    runtime = %Runtime{chat_client: InvalidSchemaChatClient}

    assert Runtime.handle_input(runtime, "hello") ==
             {:continue, runtime, "Error: Invalid model response format"}
  end
end
