defmodule AiHarness.Config do
  @app :ai_harness

  def model do
    Application.get_env(@app, :model, "gemma4:e4b")
  end

  def ollama_base_url do
    Application.get_env(@app, :ollama_base_url, "http://localhost:11434")
  end

  def prompt do
    Application.get_env(@app, :prompt, "chat>")
  end

  def welcome_message do
    Application.get_env(@app, :welcome_message, "Welcome, darling! What can I do for you?")
  end
end
