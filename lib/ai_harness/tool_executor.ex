defmodule AiHarness.ToolExecutor do
  @default_max_file_bytes 4_096

  def run("list_dir", args, opts) do
    list_dir(args["path"], opts)
  end

  def run("read_file", args, opts) do
    read_file(args["path"], opts)
  end

  def run(tool_name, _args, _opts) do
    {:error, "Unknown or invalid tool call: #{inspect(tool_name)}"}
  end

  defp list_dir(path, opts) do
    with {:ok, resolved_path} <- resolve_path(path, opts),
         :ok <- ensure_directory(resolved_path),
         {:ok, entries} <- File.ls(resolved_path) do
      mapped_entries =
        entries
        |> Enum.sort()
        |> Enum.map(fn entry_name ->
          entry_path = Path.join(path, entry_name)

          type =
            File.stat(entry_path)
            |> format_file_type_stat()

          %{name: entry_name, type: type}
        end)

      {:ok,
       %{
         path: relative_display_path(resolved_path, opts),
         entries: mapped_entries
       }}
    end
  end

  defp read_file(path, opts) do
    max_file_bytes = Keyword.get(opts, :max_file_bytes, @default_max_file_bytes)

    with {:ok, resolved_path} <- resolve_path(path, opts),
         :ok <- ensure_regular_file(resolved_path),
         {:ok, content} <- File.read(resolved_path) do
      truncated? = byte_size(content) > max_file_bytes
      limited_content = binary_part(content, 0, min(byte_size(content), max_file_bytes))

      {:ok,
       %{
         path: relative_display_path(resolved_path, opts),
         content: limited_content,
         truncated?: truncated?
       }}
    end
  end

  defp resolve_path(path, opts) do
    workspace_root = workspace_root(opts)

    resolved_path = Path.expand(path, workspace_root)
    is_within_workspace_root = inside_workspace?(resolved_path, workspace_root)

    do_resolve(resolved_path, is_within_workspace_root)
  end

  defp do_resolve(path, true), do: {:ok, path}
  defp do_resolve(_path, false), do: {:error, "Path is outside the workspace root"}

  defp workspace_root(opts) do
    opts
    |> Keyword.get(:workspace_root, File.cwd!())
    |> Path.expand()
  end

  defp inside_workspace?(path, workspace_root) do
    path == workspace_root or String.starts_with?(path, workspace_root)
  end

  defp ensure_directory(path) do
    path
    |> File.stat()
    |> handle_stat_result(:directory)
  end

  defp ensure_regular_file(path) do
    path
    |> File.stat()
    |> handle_stat_result(:regular)
  end

  defp handle_stat_result({:ok, %File.Stat{type: expected}}, expected) do
    :ok
  end

  defp handle_stat_result({:ok, %File.Stat{type: actual}}, _),
    do: {:error, "Path is not a #{format_file_type(actual)}"}

  defp handle_stat_result({:error, :enoent}, _) do
    {:error, "Path does not exist"}
  end

  defp handle_stat_result({:error, reason}, _) do
    {:error, "Error: #{reason}"}
  end

  defp format_file_type(:directory), do: "directory"
  defp format_file_type(:regular), do: "file"
  defp format_file_type(type), do: Atom.to_string(type)

  defp format_file_type_stat({:ok, %File.Stat{type: :directory}}), do: "directory"
  defp format_file_type_stat({:ok, %File.Stat{type: :regular}}), do: "file"
  defp format_file_type_stat({:ok, %File.Stat{type: type}}), do: Atom.to_string(type)
  defp format_file_type_stat({:error, _reason}), do: "unknown"

  defp relative_display_path(resolved_path, opts) do
    workspace_root = workspace_root(opts)

    case Path.relative_to(resolved_path, workspace_root) do
      "." -> "."
      relative_path -> relative_path
    end
  end
end
