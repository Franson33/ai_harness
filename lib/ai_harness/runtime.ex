defmodule AiHarness.Runtime do
  alias AiHarness.ToolExecutor
  alias AiHarness.Session
  alias AiHarness.Commands
  alias AiHarness.OllamaClient

  defstruct session: Session.new(),
            chat_client: OllamaClient,
            workspace_root: File.cwd!()

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
      |> model_messages()
      |> chat(runtime)

    handle_model_response(result, runtime, pending_session)
  end

  defp chat(messages, %__MODULE__{chat_client: chat_client}) do
    chat_client.chat(messages)
  end

  defp handle_model_response({:error, reason}, runtime, _pending_session) do
    {:continue, runtime, "Error: #{reason}"}
  end

  defp handle_model_response({:ok, raw_response}, runtime, pending_session) do
    raw_response
    |> parse_model_response()
    |> handle_parser_result(runtime, pending_session, :initial)
  end

  defp handle_tool_request(runtime, pending_session, tool_name, args) do
    tool_result = ToolExecutor.run(tool_name, args, workspace_root: runtime.workspace_root)
    tool_message = build_tool_result_message(tool_name, tool_result)

    tool_session =
      pending_session
      |> Session.add_assistant_message(tool_message)

    tool_session
    |> Session.messages()
    |> model_messages()
    |> chat(runtime)
    |> handle_tool_followup(runtime, tool_session)
  end

  defp handle_tool_followup({:error, reason}, runtime, _tool_session) do
    {:continue, runtime, "Error: #{reason}"}
  end

  defp handle_tool_followup({:ok, raw_response}, runtime, tool_session) do
    raw_response
    |> parse_model_response()
    |> handle_parser_result(runtime, tool_session, :after)
  end

  defp handle_parser_result({:final, content}, runtime, tool_session, _phase) do
    tool_session
    |> Session.add_assistant_message(content)
    |> then(&{:continue, %{runtime | session: &1}, content})
  end

  defp handle_parser_result({:tool, tool_name, args}, runtime, tool_session, :initial) do
    handle_tool_request(runtime, tool_session, tool_name, args)
  end

  defp handle_parser_result({:tool, _tool_name, _args}, runtime, _tool_session, :after) do
    {:continue, runtime, "Error: Only one tool call is allowed per turn"}
  end

  defp parse_model_response(raw_response) do
    case Jason.decode(raw_response) do
      {:ok, %{"type" => "tool", "tool" => tool, "args" => args}} when is_binary(tool) ->
        {:tool, tool, args}

      _ ->
        {:final, raw_response}
    end
  end

  defp build_tool_result_message(tool_name, {:ok, result}) do
    """
    Tool result:
    tool=#{tool_name}
    status=ok
    result=#{inspect(result)}
    """
    |> String.trim()
  end

  defp build_tool_result_message(tool_name, {:error, reason}) do
    """
    Tool result:
    tool=#{tool_name}
    status=error
    reason=#{inspect(reason)}
    """
    |> String.trim()
  end

  defp handle_command_result({:exit, new_session}, runtime) do
    {:exit, %{runtime | session: new_session}}
  end

  defp handle_command_result({:continue, new_session, output}, runtime) do
    {:continue, %{runtime | session: new_session}, output}
  end

  defp model_messages(messages) do
    [
      %{
        "role" => "system",
        "content" =>
          """
          You are operating inside a local AI harness.

          Respond in plain text or markdown — write naturally, use formatting when it helps.

          If you need to inspect the workspace before answering, call exactly one tool by responding with ONLY a JSON object and nothing else:

          {"type":"tool","tool":"list_dir","args":{"path":"."}}
          {"type":"tool","tool":"read_file","args":{"path":"relative/path.txt"}}

          Available tools:

          - list_dir — inspect the contents of a directory
          args: {"path":"relative/path"}

          - read_file — read a file's contents
          args: {"path":"relative/path.txt"}

          Rules:
          - Only call a tool when you genuinely need workspace information to answer.
          - Use only relative paths within the workspace.
          - Do not invent tool names.
          - Call at most one tool per turn.
          - When you call a tool, your entire response must be the JSON object — no text before or after.
          - After receiving a tool result, give your final answer in plain text or markdown.
          """
          |> String.trim()
      }
      | messages
    ]
  end
end
