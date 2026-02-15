defmodule TranslateMd.Translator do
  @moduledoc """
  并发翻译协调器模块。
  使用 Task.async_stream 实现并发翻译，提升大文件翻译速度。
  """

  alias TranslateMd.{Config, Ollama, Chunker, Progress, Preserver}

  # Message constants for better maintainability and potential i18n
  @msg_translation_complete "翻译完成！"
  @msg_output_file "输出文件"
  @msg_duration "耗时"

  @doc """
  翻译整个文件。

  ## 流程
  1. 读取文件内容
  2. 分块
  3. 并发翻译
  4. 合并结果
  5. 写入输出文件

  ## 参数
    - config: 配置结构体

  ## 返回值
    - `:ok` - 翻译成功
    - `{:error, reason}` - 翻译失败
  """
  @spec translate_file(Config.t()) :: :ok | {:error, String.t()}
  def translate_file(%Config{} = config) do
    Progress.show_header()
    Progress.show_config(config)

    start_time = System.monotonic_time(:millisecond)

    with {:ok, content} <- read_file(config.input_file),
         {:ok, translated} <- translate_content(content, config),
         :ok <- write_file(config.output_file, translated) do
      elapsed_ms = System.monotonic_time(:millisecond) - start_time
      show_completion_summary(config, elapsed_ms)
      :ok
    else
      {:error, reason} ->
        Progress.error(reason)
        {:error, reason}
    end
  end

  # Displays a comprehensive completion summary with timing and file info
  @spec show_completion_summary(Config.t(), non_neg_integer()) :: :ok
  defp show_completion_summary(%Config{} = config, elapsed_ms) do
    duration_str = format_duration(elapsed_ms)

    Progress.success("#{@msg_translation_complete} (#{@msg_duration}: #{duration_str})")
    Progress.success("#{@msg_output_file}: #{config.output_file}")
    Progress.show_file_stats(config.input_file, config.output_file)
  end

  # Formats milliseconds into a human-readable duration string
  @spec format_duration(non_neg_integer()) :: String.t()
  defp format_duration(ms) when ms < 1000, do: "#{ms}ms"

  defp format_duration(ms) when ms < 60_000 do
    seconds = Float.round(ms / 1000, 1)
    "#{seconds}s"
  end

  defp format_duration(ms) do
    minutes = div(ms, 60_000)
    seconds = Float.round(rem(ms, 60_000) / 1000, 1)
    "#{minutes}m #{seconds}s"
  end

  @doc """
  翻译文本内容。

  ## 流程
  1. 提取不可翻译内容（代码块、URL、base64图片等）并替换为占位符
  2. 分块翻译
  3. 还原占位符为原始内容

  ## 参数
    - content: 要翻译的文本内容
    - config: 配置结构体

  ## 返回值
    - `{:ok, translated_content}` - 翻译成功
    - `{:error, reason}` - 翻译失败
  """
  @spec translate_content(String.t(), Config.t()) :: {:ok, String.t()} | {:error, String.t()}
  def translate_content(content, %Config{} = config) do
    # 1. 保留不可翻译内容（代码块、URL、base64图片等）
    {preserved_content, placeholders} = Preserver.preserve(content)

    preserved_count = map_size(placeholders)

    if preserved_count > 0 do
      Progress.info("保留了 #{preserved_count} 个不可翻译内容块")
      Progress.debug("保留内容统计: #{inspect(Preserver.stats(placeholders))}", config.debug)
    end

    # 2. 分块
    chunks = Chunker.split(preserved_content, config.chunk_size)
    total = length(chunks)

    Progress.info("文件大小: #{String.length(content)} 字符")
    Progress.info("分块数量: #{total}")

    Progress.debug(
      fn -> "分块详情: #{inspect(Chunker.stats(preserved_content, config.chunk_size))}" end,
      config.debug
    )

    IO.puts("")

    if total == 0 do
      {:ok, ""}
    else
      # 3. 翻译并还原
      case translate_chunks(chunks, config) do
        {:ok, translated} ->
          # 还原不可翻译内容
          restored = Preserver.restore(translated, placeholders)
          {:ok, restored}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  并发翻译所有文本块。

  使用 Task.async_stream 实现并发，通过 max_concurrency 控制并发数。
  即使并发执行，结果也会按原始顺序合并。

  ## 参数
    - chunks: 带索引的块列表 `[{index, content}, ...]`
    - config: 配置结构体

  ## 返回值
    - `{:ok, merged_content}` - 翻译成功
    - `{:error, reason}` - 翻译失败
  """
  @spec translate_chunks([{non_neg_integer(), String.t()}], Config.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def translate_chunks(chunks, %Config{} = config) do
    total = length(chunks)

    # 使用 Agent 来跟踪进度
    {:ok, progress_agent} = Agent.start_link(fn -> 0 end)
    Progress.show(0, total)

    results =
      chunks
      |> Task.async_stream(
        fn {index, chunk} ->
          Progress.debug("开始翻译块 #{index + 1}/#{total}", config.debug)

          result = Ollama.translate(chunk, config)

          # 更新进度
          completed = Agent.get_and_update(progress_agent, fn count -> {count + 1, count + 1} end)
          Progress.show(completed, total)

          Progress.debug("完成翻译块 #{index + 1}/#{total}", config.debug)

          {index, result}
        end,
        max_concurrency: config.concurrency,
        timeout: :infinity,
        ordered: false
      )
      |> Enum.map(fn {:ok, result} -> result end)

    Agent.stop(progress_agent)

    # 检查是否有错误
    errors = Enum.filter(results, fn {_, result} -> match?({:error, _}, result) end)

    if errors != [] do
      error_messages =
        errors
        |> Enum.map(fn {index, {:error, reason}} -> "块 #{index + 1}: #{reason}" end)
        |> Enum.join("\n")

      {:error, "部分翻译失败:\n#{error_messages}"}
    else
      # 按索引排序并合并结果
      merged =
        results
        |> Enum.sort_by(fn {index, _} -> index end)
        |> Enum.map(fn {_, {:ok, content}} -> content end)
        |> Enum.join("\n\n")

      {:ok, merged}
    end
  end

  # 读取输入文件
  defp read_file(path) do
    case File.read(path) do
      {:ok, content} ->
        {:ok, content}

      {:error, :enoent} ->
        {:error, "文件不存在: #{path}"}

      {:error, reason} ->
        {:error, "读取文件失败: #{inspect(reason)}"}
    end
  end

  # 写入输出文件
  defp write_file(path, content) do
    case File.write(path, content) do
      :ok ->
        :ok

      {:error, reason} ->
        {:error, "写入文件失败: #{inspect(reason)}"}
    end
  end
end
