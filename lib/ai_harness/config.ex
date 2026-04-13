defmodule AiHarness.Config do
  @app :ai_harness

  @welcome_message """
  +------------------+
  | Anton's Code :)  |
  +------------------+
  """

  def model do
    Application.get_env(@app, :model, "gemma4-fast")
  end

  def ollama_base_url do
    Application.get_env(@app, :ollama_base_url, "http://localhost:11434")
  end

  def prompt do
    Application.get_env(@app, :prompt, "chat>")
  end

  def ollama_receive_timeout do
    Application.get_env(@app, :ollama_receive_timeout, 120_000)
  end

  def welcome_message do
    Application.get_env(@app, :welcome_message, @welcome_message)
  end
end
