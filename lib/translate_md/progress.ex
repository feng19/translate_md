defmodule TranslateMd.Progress do
  @moduledoc """
  进度显示模块。
  提供终端进度条和状态信息显示功能。
  """

  # ANSI color codes using IO.ANSI for standardization and maintainability.
  # IO.ANSI provides well-tested escape sequences and respects IO.ANSI.enabled?/0.
  @red IO.ANSI.red()
  @green IO.ANSI.green()
  @yellow IO.ANSI.yellow()
  @blue IO.ANSI.blue()
  @reset IO.ANSI.reset()

  @doc """
  显示翻译进度条。

  ## 参数
    - current: 当前完成的数量
    - total: 总数量
  """
  @spec show(non_neg_integer(), pos_integer()) :: :ok
  def show(current, total) when total > 0 do
    percent = round(current / total * 100)
    bar_length = 50
    filled = round(percent * bar_length / 100)

    bar =
      String.duplicate("█", filled) <>
        String.duplicate("░", bar_length - filled)

    IO.write("\r#{@yellow}翻译进度: [#{@reset}#{bar}#{@yellow}] #{percent}%#{@reset}")

    if current == total do
      IO.puts("")
    end

    :ok
  end

  @doc """
  打印成功消息。
  """
  @spec success(String.t()) :: :ok
  def success(message) do
    IO.puts("#{@green}✓ #{message}#{@reset}")
  end

  @doc """
  打印错误消息。
  """
  @spec error(String.t()) :: :ok
  def error(message) do
    IO.puts(:stderr, "#{@red}✗ 错误: #{message}#{@reset}")
  end

  @doc """
  打印警告消息。
  """
  @spec warning(String.t()) :: :ok
  def warning(message) do
    IO.puts("#{@yellow}⚠ 警告: #{message}#{@reset}")
  end

  @doc """
  打印信息消息。
  """
  @spec info(String.t()) :: :ok
  def info(message) do
    IO.puts("#{@blue}ℹ #{message}#{@reset}")
  end

  @doc """
  打印调试消息（仅在 debug 模式下显示）。
  """
  @spec debug(String.t(), boolean()) :: :ok
  def debug(message, debug_enabled) do
    if debug_enabled do
      IO.puts(:stderr, "#{@blue}[DEBUG] #{message}#{@reset}")
    end

    :ok
  end

  @doc """
  显示任务开始的标题框。
  """
  @spec show_header() :: :ok
  def show_header do
    IO.puts("")
    IO.puts("#{@green}╔═══════════════════════════════════════════╗#{@reset}")
    IO.puts("#{@green}║          开始翻译任务                     ║#{@reset}")
    IO.puts("#{@green}╚═══════════════════════════════════════════╝#{@reset}")
    IO.puts("")
  end

  @doc """
  显示帮助信息的标题框。
  """
  @spec show_help_header() :: :ok
  def show_help_header do
    IO.puts("#{@green}╔═══════════════════════════════════════════╗#{@reset}")
    IO.puts("#{@green}║    Ollama Markdown 翻译工具 (Elixir)      ║#{@reset}")
    IO.puts("#{@green}╚═══════════════════════════════════════════╝#{@reset}")
  end

  @doc """
  显示配置信息。
  """
  @spec show_config(TranslateMd.Config.t()) :: :ok
  def show_config(config) do
    info("输入文件: #{config.input_file}")
    info("输出文件: #{config.output_file}")
    info("使用模型: #{config.model}")
    info("块大小: #{config.chunk_size} 字符")
    info("并发数: #{config.concurrency}")
    IO.puts("")
  end

  @doc """
  显示文件统计信息。
  """
  @spec show_file_stats(String.t(), String.t()) :: :ok
  def show_file_stats(input_file, output_file) do
    input_stat = File.stat!(input_file)
    output_stat = File.stat!(output_file)

    input_lines = input_file |> File.read!() |> String.split("\n") |> length()
    output_lines = output_file |> File.read!() |> String.split("\n") |> length()

    IO.puts("")
    info("原文件: #{input_stat.size} 字节, #{input_lines} 行")
    info("译文件: #{output_stat.size} 字节, #{output_lines} 行")
  end
end
