defmodule AiHarness.RuntimeTest do
  use ExUnit.Case, async: true

  alias AiHarness.Runtime
  alias AiHarness.Session

  defmodule SuccessChatClient do
    def chat(_messages), do: {:ok, "stub response"}
  end

  defmodule ErrorChatClient do
    def chat(_messages), do: {:error, "timeout"}
  end

  defmodule NonToolJsonChatClient do
    def chat(_messages), do: {:ok, ~s({"foo":"bar"})}
  end

  defmodule ToolThenFinalChatClient do
    def chat(messages) do
      case List.last(messages) do
        %{"role" => "user"} ->
          {:ok, ~s({"type":"tool","tool":"read_file","args":{"path":"README.md"}})}

        %{"role" => "assistant", "content" => content} ->
          if String.contains?(content, "Tool result:") do
            {:ok, "I found the file contents"}
          else
            {:ok, "unexpected"}
          end
      end
    end
  end

  defmodule ToolThenToolChatClient do
    def chat(_messages) do
      {:ok, ~s({"type":"tool","tool":"list_dir","args":{"path":"."}})}
    end
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

  test "handle_input/2 treats non-tool json as a plain text final answer" do
    runtime = %Runtime{chat_client: NonToolJsonChatClient}

    assert Runtime.handle_input(runtime, "hello") ==
             {:continue,
              %Runtime{
                session: %Session{
                  messages: [
                    %{"role" => "user", "content" => "hello"},
                    %{"role" => "assistant", "content" => ~s({"foo":"bar"})}
                  ]
                },
                chat_client: NonToolJsonChatClient
              }, ~s({"foo":"bar"})}
  end

  test "handle_input/2 executes one tool call and then returns the final answer" do
    workspace_root =
      System.tmp_dir!()
      |> Path.join("ai_harness_runtime_tool_test_#{System.unique_integer([:positive])}")

    File.mkdir_p!(workspace_root)
    File.write!(Path.join(workspace_root, "README.md"), "hello from tool test\n")

    on_exit(fn -> File.rm_rf!(workspace_root) end)

    runtime = %Runtime{
      chat_client: ToolThenFinalChatClient,
      workspace_root: workspace_root
    }

    assert {:continue, updated_runtime, "I found the file contents"} =
             Runtime.handle_input(runtime, "inspect the readme")

    assert updated_runtime.chat_client == ToolThenFinalChatClient
    assert updated_runtime.workspace_root == workspace_root

    assert [
             %{"role" => "user", "content" => "inspect the readme"},
             %{"role" => "assistant", "content" => tool_message},
             %{"role" => "assistant", "content" => "I found the file contents"}
           ] = updated_runtime.session.messages

    assert tool_message =~ "Tool result:"
    assert tool_message =~ "tool=read_file"
    assert tool_message =~ "status=ok"
    assert tool_message =~ "README.md"
  end

  test "handle_input/2 rejects a second tool call in the same turn" do
    workspace_root =
      System.tmp_dir!()
      |> Path.join("ai_harness_runtime_tool_limit_test_#{System.unique_integer([:positive])}")

    File.mkdir_p!(workspace_root)
    on_exit(fn -> File.rm_rf!(workspace_root) end)

    runtime = %Runtime{
      chat_client: ToolThenToolChatClient,
      workspace_root: workspace_root
    }

    assert Runtime.handle_input(runtime, "inspect the project") ==
             {:continue, runtime, "Error: Only one tool call is allowed per turn"}
  end
end
