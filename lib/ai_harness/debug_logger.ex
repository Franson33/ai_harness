defmodule AiHarness.DebugLogger do
  @log_path "/tmp/ai_harness_debug.log"

  def log_request(message) do
    write("REQUEST", Jason.encode!(message))
  end

  def log_response(raw) do
    write("RESPONSE", raw)
  end

  defp write(label, content) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M:%S")
    entry = "[#{timestamp}] #{label}\n#{content}\n\n---\n"

    File.write(@log_path, entry, [:append])
  end
end
