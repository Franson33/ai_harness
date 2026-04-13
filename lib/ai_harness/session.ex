defmodule AiHarness.Session do
  defstruct messages: []

  def new() do
    %__MODULE__{}
  end

  def messages(%__MODULE__{messages: messages}) do
    messages
  end

  def add_user_message(%__MODULE__{} = session, content) do
    add_message(session, "user", content)
  end

  def add_assistant_message(%__MODULE__{} = session, content) do
    add_message(session, "assistant", content)
  end

  def clear(%__MODULE__{} = session) do
    %{session | messages: []}
  end

  def history_lines(%__MODULE__{messages: []}) do
    ["No messages yet."]
  end

  def history_lines(%__MODULE__{messages: messages}) do
    Enum.map(messages, fn %{"role" => role, "content" => content} ->
      "#{role}: #{content}"
    end)
  end

  def add_message(%__MODULE__{} = session, role, content) do
    new_message = %{"role" => role, "content" => String.trim(content)}

    %{session | messages: session.messages ++ [new_message]}
  end
end
