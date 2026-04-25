defmodule AiHarness.ToolExecutorTest do
  use ExUnit.Case, async: true

  alias AiHarness.ToolExecutor

  setup do
    workspace_root =
      System.tmp_dir!()
      |> Path.join("ai_harness_tool_executor_test_#{System.unique_integer([:positive])}")

    File.mkdir_p!(workspace_root)

    File.write!(Path.join(workspace_root, "README.md"), "hello from test\n")
    File.mkdir_p!(Path.join(workspace_root, "lib"))
    File.write!(Path.join(workspace_root, "lib/example.ex"), "defmodule Example do\nend\n")

    on_exit(fn -> File.rm_rf!(workspace_root) end)

    {:ok, workspace_root: workspace_root}
  end

  test "run/3 executes list_dir inside the workspace root", %{workspace_root: workspace_root} do
    assert ToolExecutor.run("list_dir", %{"path" => "."}, workspace_root: workspace_root) ==
             {:ok,
              %{
                path: ".",
                entries: [
                  %{name: "README.md", type: "file"},
                  %{name: "lib", type: "directory"}
                ]
              }}
  end

  test "run/3 executes read_file inside the workspace root", %{workspace_root: workspace_root} do
    assert ToolExecutor.run("read_file", %{"path" => "README.md"}, workspace_root: workspace_root) ==
             {:ok, %{path: "README.md", content: "hello from test\n", truncated?: false}}
  end

  test "read_file/2 truncates large files", %{workspace_root: workspace_root} do
    File.write!(Path.join(workspace_root, "large.txt"), "abcdef")

    assert ToolExecutor.read_file("large.txt", workspace_root: workspace_root, max_file_bytes: 3) ==
             {:ok, %{path: "large.txt", content: "abc", truncated?: true}}
  end

  test "resolve_path/2 rejects paths outside the workspace root", %{workspace_root: workspace_root} do
    assert ToolExecutor.resolve_path("../outside.txt", workspace_root: workspace_root) ==
             {:error, "Path is outside the workspace root"}
  end

  test "list_dir/2 rejects non-directory paths", %{workspace_root: workspace_root} do
    assert ToolExecutor.list_dir("README.md", workspace_root: workspace_root) ==
             {:error, "Path is not a directory"}
  end

  test "read_file/2 rejects directories", %{workspace_root: workspace_root} do
    assert ToolExecutor.read_file("lib", workspace_root: workspace_root) ==
             {:error, "Path is not a regular file"}
  end

  test "run/3 rejects unknown tools", %{workspace_root: workspace_root} do
    assert ToolExecutor.run("rm_rf", %{"path" => "."}, workspace_root: workspace_root) ==
             {:error, "Unknown or invalid tool call: rm_rf"}
  end
end
