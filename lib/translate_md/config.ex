defmodule TranslateMd.Config do
  @moduledoc """
  配置管理模块，集中管理所有翻译相关的配置项。
  """

  @default_system_prompt """
  You are a professional technical translator. Translate the following English technical documentation to Chinese. Keep all markdown formatting, code blocks, links, and technical terms accurate. Preserve the original structure and only translate the text content. For well-known technical terms, you may keep the English term with Chinese translation in parentheses on first occurrence.
  """

  defstruct [
    :input_file,
    :output_file,
    model: "translategemma",
    system_prompt: @default_system_prompt,
    chunk_size: 1200,
    temperature: 0.3,
    concurrency: 16,
    debug: false,
    ollama_url: "http://localhost:11434"
  ]

  @type t :: %__MODULE__{
          input_file: String.t() | nil,
          output_file: String.t() | nil,
          model: String.t(),
          system_prompt: String.t(),
          chunk_size: pos_integer(),
          temperature: float(),
          concurrency: pos_integer(),
          debug: boolean(),
          ollama_url: String.t()
        }

  @doc """
  创建新的配置结构体。

  ## 参数
    - opts: 配置选项的关键字列表

  ## 示例
      iex> TranslateMd.Config.new(model: "gemma2", concurrency: 8)
      %TranslateMd.Config{model: "gemma2", concurrency: 8, ...}
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    struct(__MODULE__, opts)
  end

  @doc """
  获取默认的 System Prompt。
  """
  @spec default_system_prompt() :: String.t()
  def default_system_prompt, do: @default_system_prompt

  @doc """
  根据输入文件名生成默认的输出文件名。
  将 `.md` 替换为 `_zh.md`。
  """
  @spec default_output_file(String.t()) :: String.t()
  def default_output_file(input_file) do
    ext = Path.extname(input_file)
    basename = Path.basename(input_file, ext)
    dirname = Path.dirname(input_file)

    new_filename = "#{basename}_zh#{ext}"

    case dirname do
      "." -> new_filename
      _ -> Path.join(dirname, new_filename)
    end
  end
end
