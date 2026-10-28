defmodule TranslateMd.CLI do
  @moduledoc """
  命令行接口模块。
  解析命令行参数并执行翻译任务。
  """

  alias TranslateMd.{Config, Ollama, Translator, Progress}

  @doc """
  escript 入口点。
  """
  @spec main([String.t()]) :: no_return()
  def main(args) do
    args
    |> parse_args()
    |> run()
  end

  @doc """
  解析命令行参数。
  """
  @spec parse_args([String.t()]) ::
          {:ok, Config.t()} | {:help} | {:show_prompt} | {:error, String.t()}
  def parse_args(args) do
    {opts, remaining, invalid} =
      OptionParser.parse(args,
        strict: [
          help: :boolean,
          model: :string,
          api: :string,
          url: :string,
          output: :string,
          prompt: :string,
          chunk_size: :integer,
          temperature: :float,
          concurrency: :integer,
          force: :boolean,
          debug: :boolean,
          show_default_prompt: :boolean
        ],
        aliases: [
          h: :help,
          m: :model,
          u: :url,
          o: :output,
          p: :prompt,
          s: :chunk_size,
          t: :temperature,
          c: :concurrency,
          f: :force,
          d: :debug
        ]
      )

    cond do
      opts[:help] ->
        {:help}

      opts[:show_default_prompt] ->
        {:show_prompt}

      opts[:api] not in [nil, "openai", "ollama"] ->
        {:error, "--api 只支持 openai 或 ollama"}

      invalid != [] ->
        {:error, "未知选项: #{inspect(invalid)}"}

      remaining == [] ->
        {:error, "请指定输入文件"}

      true ->
        [input_file | _] = remaining
        build_config(input_file, opts)
    end
  end

  # 构建配置
  defp build_config(input_file, opts) do
    output_file = opts[:output] || Config.default_output_file(input_file)

    api = opts[:api] && String.to_existing_atom(opts[:api])

    config_opts =
      [
        input_file: input_file,
        output_file: output_file
      ]
      |> maybe_add(:api, api)
      |> maybe_add(:url, opts[:url] || default_url(api))
      |> maybe_add(:model, opts[:model])
      |> maybe_add(:system_prompt, opts[:prompt])
      |> maybe_add(:chunk_size, opts[:chunk_size])
      |> maybe_add(:temperature, opts[:temperature])
      |> maybe_add(:concurrency, opts[:concurrency])
      |> maybe_add(:force, opts[:force])
      |> maybe_add(:debug, opts[:debug])

    {:ok, Config.new(config_opts)}
  end

  defp default_url(:ollama), do: "http://localhost:11434"
  defp default_url(_), do: nil

  defp maybe_add(list, _key, nil), do: list
  defp maybe_add(list, key, value), do: Keyword.put(list, key, value)

  # 执行翻译任务
  defp run({:help}) do
    show_help()
    System.halt(0)
  end

  defp run({:show_prompt}) do
    show_default_prompt()
    System.halt(0)
  end

  defp run({:error, reason}) do
    Progress.error(reason)
    IO.puts("")
    show_help()
    System.halt(1)
  end

  defp run({:ok, config}) do
    # 检查输入文件是否存在
    unless File.exists?(config.input_file) do
      Progress.error("文件不存在: #{config.input_file}")
      System.halt(1)
    end

    # 检查输出文件是否已存在
    if not config.force && File.exists?(config.output_file) do
      Progress.warning("输出文件已存在: #{config.output_file}")

      case IO.gets("是否覆盖? (y/N): ") do
        input when input in ["y\n", "Y\n"] ->
          :ok

        _ ->
          Progress.info("操作已取消")
          System.halt(0)
      end
    end

    # 检查 API 服务
    case Ollama.check_service(config) do
      :ok ->
        Progress.success("API 服务运行正常")

      {:error, reason} ->
        Progress.error(reason)
        System.halt(1)
    end

    # 检查模型是否存在
    case Ollama.check_model(config) do
      :ok ->
        :ok

      {:error, :not_found} ->
        Progress.warning("模型 '#{config.model}' 未找到")

        if config.api == :ollama,
          do: Progress.info("请先拉取模型: ollama pull #{config.model}"),
          else: Progress.info("请确认服务中已加载该模型")
        System.halt(1)
    end

    # 执行翻译
    case Translator.translate_file(config) do
      :ok ->
        System.halt(0)

      {:error, _reason} ->
        System.halt(1)
    end
  end

  # 显示帮助信息
  defp show_help do
    Progress.show_help_header()
    config = Config.new()

    IO.puts("""

    用法:
      translate_md [选项] <输入文件.md>

    选项:
      -h, --help              显示帮助信息
      --api TYPE              接口类型: openai | ollama (默认: #{config.api})
      -u, --url URL           服务地址 (默认: #{config.url}；ollama 为 http://localhost:11434)
      -m, --model MODEL       指定模型 (默认: #{config.model})
      -o, --output FILE       指定输出文件名 (默认: 输入文件名_zh.md)
      -p, --prompt PROMPT     自定义 System Prompt
      -s, --chunk-size SIZE   每次翻译的字符数 (默认: #{config.chunk_size})
      -t, --temperature TEMP  模型温度 (默认: #{config.temperature})
      -c, --concurrency NUM   最大并发数 (默认: #{config.concurrency})
      -f, --force             强制覆盖输出文件
      -d, --debug             启用调试模式
      --show-default-prompt   显示默认的 System Prompt

    示例:
      # 基本使用
      translate_md README.md

      # 指定模型和输出文件
      translate_md -m gemma2 -o 输出.md 文档.md

      # 使用 8 个并发
      translate_md -c 8 input.md

      # 自定义翻译提示
      translate_md -p "翻译为简体中文，保持专业术语" input.md

      # 调试模式
      translate_md --debug input.md
    """)
  end

  # 显示默认 System Prompt
  defp show_default_prompt do
    IO.puts("""
    ═══════════════════════════════════════════
    默认 System Prompt:
    ═══════════════════════════════════════════

    #{Config.default_system_prompt()}
    """)
  end
end
