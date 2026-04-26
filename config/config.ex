import Config

config :ai_harness,
  model: "gemma4-fast",
  ollama_base_url: "http://localhost:11434",
  ollama_receive_timeout: 120_000,
  prompt: "chat> ",
  welcome_message: "Welcome, darling! What can I do for you?"
