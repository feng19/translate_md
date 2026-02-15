defmodule TranslateMd do
  @moduledoc """
  TranslateMd - 使用 Ollama 翻译 Markdown 文档的工具。

  支持并发翻译大文件，提升翻译速度。

  ## 功能特点

  - 使用 Ollama API 将英文 Markdown 翻译为中文
  - 并发分块翻译，加速大文件处理
  - 保持 Markdown 格式、代码块、链接和技术术语
  - 支持命令行参数配置
  - 显示实时翻译进度

  ## 使用方式

  ### 作为命令行工具

      # 编译为可执行文件
      mix escript.build

      # 基本使用
      ./translate_md README.md

      # 指定并发数
      ./translate_md -c 8 input.md

  ### 作为库使用

      config = TranslateMd.Config.new(
        input_file: "README.md",
        output_file: "README_zh.md",
        concurrency: 4
      )

      TranslateMd.Translator.translate_file(config)
  """

  alias TranslateMd.{Config, Translator}

  @doc """
  翻译 Markdown 文件的便捷函数。

  ## 参数
    - input_file: 输入文件路径
    - opts: 可选配置项

  ## 示例

      TranslateMd.translate("README.md")
      TranslateMd.translate("README.md", output: "README_zh.md", concurrency: 8)
  """
  @spec translate(String.t(), keyword()) :: :ok | {:error, String.t()}
  def translate(input_file, opts \\ []) do
    output_file = opts[:output] || Config.default_output_file(input_file)

    config =
      Config.new(
        Keyword.merge(opts,
          input_file: input_file,
          output_file: output_file
        )
      )

    Translator.translate_file(config)
  end
end
