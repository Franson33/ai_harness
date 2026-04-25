defmodule AiHarness.CLI do
  alias AiHarness.Config
  alias AiHarness.Runtime

  def start() do
    Config.welcome_message()
    |> IO.puts()

    Runtime.new()
    |> loop()

    :ok
  end

  defp loop(runtime) do
    runtime
    |> read_input()
    |> handle_read_result(runtime)
  end

  defp read_input(_runtime) do
    Config.prompt()
    |> IO.gets()
  end

  defp handle_read_result(:eof, _runtime) do
    IO.puts("Goodbye!")
    :ok
  end

  defp handle_read_result({:error, reason}, runtime) do
    IO.puts("Input error: #{inspect(reason)}")
    loop(runtime)
  end

  defp handle_read_result(input, runtime) when is_binary(input) do
    runtime
    |> Runtime.handle_input(input)
    |> handle_action()
  end

  defp handle_action({:continue, runtime}) do
    loop(runtime)
  end

  defp handle_action({:continue, runtime, output}) do
    IO.puts(output)
    loop(runtime)
  end

  defp handle_action({:exit, _session}) do
    IO.puts("Goodbye!")
    :ok
  end
end
