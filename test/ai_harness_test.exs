defmodule AiHarnessTest do
  use ExUnit.Case
  doctest AiHarness

  test "greets the world" do
    assert AiHarness.hello() == :world
  end
end
