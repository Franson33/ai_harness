# PLAN.md

## Project Goal

Build a minimal local **AI harness** in Elixir, starting with a terminal chat app that talks to a local model through Ollama.

This project should evolve in small, stable steps:

1. **v0:** terminal chat with conversation history
2. **v1:** cleaner internal architecture and structured response handling
3. **v2:** read-only tools like directory listing and grep
4. **v3:** write tools like file editing
5. **v4:** multi-step tool loop that starts becoming a real agent

The immediate goal is **not** to build a full agent.
The immediate goal is to build a reliable local **LLM shell / harness foundation**.

---

## Initial Scope

### We are building first

A CLI app that:

- accepts user input in the terminal
- sends messages to a local Ollama-hosted model
- receives the model response
- prints the response nicely
- keeps conversation history in memory for the current session
- supports a few shell commands like `/clear`, `/history`, `/exit`

### We are explicitly NOT building yet

Do **not** add these in the first pass:

- tool execution
- file writing
- grep integration
- autonomous loops
- planning
- memory persistence
- multi-agent systems
- Phoenix UI
- vector DB / embeddings
- background jobs

---

## Architecture Principles

### 1. Build in layers

Do not mix chat, tools, and agent logic too early.

Layers:

- **Layer 1:** plain chat harness
- **Layer 2:** structured outputs
- **Layer 3:** tool-capable assistant
- **Layer 4:** agent loop

### 2. Keep modules small and separate

Even the simplest version should avoid becoming one giant script.

### 3. The harness owns control

The model should generate responses.
The harness should own:

- session state
- request formatting
- response parsing
- retries
- logging
- future tool execution
- safety boundaries

### 4. Start with in-memory state

Persistence can come later.

### 5. Design for future tools now

Even before implementing tools, structure the code so tools can be added cleanly later.

---

## Tech Assumptions

- Language: **Elixir**
- Runtime: **BEAM / OTP**
- Local model host: **Ollama**
- Initial model: user already has a local model available
- Interface: terminal / CLI only

---

## Phase 0: Working Terminal Chat

### Objective

Get a working REPL-style terminal app connected to the local model.

### User experience
