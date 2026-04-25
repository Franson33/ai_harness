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

  test "run/3 truncates large files for read_file", %{workspace_root: workspace_root} do
    File.write!(Path.join(workspace_root, "large.txt"), "abcdef")

    assert ToolExecutor.run("read_file", %{"path" => "large.txt"},
             workspace_root: workspace_root,
             max_file_bytes: 3
           ) ==
             {:ok, %{path: "large.txt", content: "abc", truncated?: true}}
  end

  test "run/3 rejects read_file paths outside the workspace root", %{workspace_root: workspace_root} do
    assert ToolExecutor.run("read_file", %{"path" => "../outside.txt"}, workspace_root: workspace_root) ==
             {:error, "Path is outside the workspace root"}
  end

  test "run/3 reports the actual type when list_dir receives a file path", %{workspace_root: workspace_root} do
    assert ToolExecutor.run("list_dir", %{"path" => "README.md"}, workspace_root: workspace_root) ==
             {:error, "Path is not a file"}
  end

  test "run/3 rejects read_file on directories", %{workspace_root: workspace_root} do
    assert ToolExecutor.run("read_file", %{"path" => "lib"}, workspace_root: workspace_root) ==
             {:error, "Path is not a directory"}
  end

  test "run/3 rejects unknown tools", %{workspace_root: workspace_root} do
    assert ToolExecutor.run("rm_rf", %{"path" => "."}, workspace_root: workspace_root) ==
             {:error, "Unknown or invalid tool call: \"rm_rf\""}
  end
end
