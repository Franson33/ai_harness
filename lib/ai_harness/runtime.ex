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

  defp handle_parser_result({:error, reason}, runtime, _tool_session, _phase) do
    {:continue, runtime, "Error: #{reason}"}
  end

  defp parse_model_response(raw_response) do
    with {:ok, decoded} <- Jason.decode(raw_response),
         {:ok, parsed} <- parse_decoded_response(decoded) do
      parsed
    else
      {:error, reason} when is_binary(reason) ->
        {:error, reason}

      {:error, reason} ->
        {:error, Exception.message(reason)}
    end
  end

  defp parse_decoded_response(%{"type" => "final", "content" => content})
       when is_binary(content) do
    {:ok, {:final, content}}
  end

  defp parse_decoded_response(%{"type" => "tool", "tool" => tool, "args" => args})
       when is_binary(tool) do
    {:ok, {:tool, tool, args}}
  end

  defp parse_decoded_response(_decoded) do
    {:error, "Invalid model response format"}
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

          You must respond with valid JSON only.
          Your entire response must be a single valid JSON object.
          Do not write any text before or after the JSON.
          Do not use markdown.
          Do not use code fences.
          If you fail to return JSON, your response will be rejected.

          Allowed response formats:

          {"type":"final","content":"your answer here"}

          {"type":"tool","tool":"list_dir","args":{"path":"."}}

          {"type":"tool","tool":"read_file","args":{"path":"relative/path.txt"}}

          Available tools:

          - list_dir
            Use this to inspect the contents of a directory inside the workspace.
            Arguments:
            {"path":"relative/path"}

          - read_file
            Use this to read a file inside the workspace.
            Arguments:
            {"path":"relative/path.txt"}

          Rules:
          - Use only the listed tools.
          - Use only relative workspace paths.
          - Do not invent tool names.
          - Call at most one tool in a turn.
          - If no tool is needed, return a final answer.
          - After receiving a tool result, return a final answer.
          """
          |> String.trim()
      }
      | messages
    ]
  end
end
