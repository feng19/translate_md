defmodule TranslateMd.Ollama do
  @moduledoc """
  Ollama HTTP API 客户端模块。
  封装与 Ollama 服务的所有交互。
  """

  alias TranslateMd.Config

  @doc """
  检查 Ollama 服务是否运行。

  ## 返回值
    - `:ok` - 服务正常运行
    - `{:error, reason}` - 服务不可用
  """
  @spec check_service(Config.t()) :: :ok | {:error, String.t()}
  def check_service(%Config{ollama_url: url}) do
    case Req.get("#{url}/api/tags", receive_timeout: 5000) do
      {:ok, %{status: 200}} ->
        :ok

      {:ok, %{status: status}} ->
        {:error, "Ollama 服务返回异常状态码: #{status}"}

      {:error, %Req.TransportError{reason: :econnrefused}} ->
        {:error, "Ollama 服务未运行，请启动服务: ollama serve"}

      {:error, reason} ->
        {:error, "无法连接 Ollama 服务: #{inspect(reason)}"}
    end
  end

  @doc """
  检查指定模型是否存在。

  ## 返回值
    - `:ok` - 模型存在
    - `{:error, :not_found}` - 模型不存在
  """
  @spec check_model(Config.t()) :: :ok | {:error, :not_found}
  def check_model(%Config{ollama_url: url, model: model}) do
    case Req.get("#{url}/api/tags") do
      {:ok, %{status: 200, body: %{"models" => models}}} ->
        model_exists =
          Enum.any?(models, fn m ->
            m["name"] == model || String.starts_with?(m["name"], "#{model}:")
          end)

        if model_exists, do: :ok, else: {:error, :not_found}

      _ ->
        {:error, :not_found}
    end
  end

  @doc """
  翻译单个文本块。

  ## 参数
    - text: 要翻译的文本
    - config: 配置结构体

  ## 返回值
    - `{:ok, translated_text}` - 翻译成功
    - `{:error, reason}` - 翻译失败
  """
  @spec translate(String.t(), Config.t()) :: {:ok, String.t()} | {:error, String.t()}
  def translate(text, %Config{} = config) do
    payload = build_payload(text, config)

    case Req.post("#{config.ollama_url}/api/generate",
           json: payload,
           receive_timeout: :infinity
         ) do
      {:ok, %{status: 200, body: %{"response" => response}}} ->
        # LLM 有时会在翻译结果周围添加代码块包装，需要去除
        cleaned = response |> String.trim() |> strip_code_block_wrapper()
        {:ok, cleaned}

      {:ok, %{status: 200, body: body}} ->
        {:error, "API 响应格式异常: #{inspect(body)}"}

      {:ok, %{status: status, body: body}} ->
        {:error, "API 返回状态码 #{status}: #{inspect(body)}"}

      {:error, %Req.TransportError{reason: reason}} ->
        {:error, "网络错误: #{inspect(reason)}"}

      {:error, reason} ->
        {:error, "请求失败: #{inspect(reason)}"}
    end
  end

  @doc """
  构建 Ollama API 请求的 payload。
  """
  @spec build_payload(String.t(), Config.t()) :: map()
  def build_payload(text, %Config{} = config) do
    %{
      model: config.model,
      prompt: build_prompt(text),
      system: config.system_prompt,
      stream: false,
      options: %{
        temperature: config.temperature
      }
    }
  end

  defp build_prompt(text) do
    "Translate the following English text to Chinese. Maintain all markdown formatting:\n\n#{text}"
  end

  @doc """
  去除 LLM 可能添加的代码块包装。

  LLM 有时会在翻译结果周围添加 ``` 代码块标记，这会破坏 Markdown 格式。
  此函数检测并去除这种包装，同时保留内容中的正常代码块。

  ## 参数
    - text: 可能被代码块包装的文本

  ## 返回值
    - 去除包装后的文本

  ## 示例
      iex> Ollama.strip_code_block_wrapper("```\\n# Title\\n```")
      "# Title"

      iex> Ollama.strip_code_block_wrapper("# Title\\n\\n```python\\ncode\\n```")
      "# Title\\n\\n```python\\ncode\\n```"
  """
  @spec strip_code_block_wrapper(String.t()) :: String.t()
  def strip_code_block_wrapper(text) when is_binary(text) do
    trimmed = String.trim(text)

    if trimmed == "" do
      ""
    else
      # 检查是否以 ``` 开头（可能带语言标识符，可能有前导空格）
      if String.match?(trimmed, ~r/^\s*```[a-zA-Z]*\s*\n/) do
        # 检查是否以 ``` 结尾（可能有尾随空格）
        if String.match?(trimmed, ~r/\n\s*```\s*$/) do
          # 完整的代码块包装，去除首尾
          trimmed
          |> String.replace(~r/^\s*```[a-zA-Z]*\s*\n/, "")
          |> String.replace(~r/\n\s*```\s*$/, "")
          |> String.trim()
        else
          # 只有开头的 ```，可能是 LLM 忘记闭合或者内容中有其他 ```
          # 检查是否整个内容看起来像是被包装的（开头是 ``` 且内容中没有对应的结构）
          strip_opening_fence_if_wrapper(trimmed)
        end
      else
        trimmed
      end
    end
  end

  # 处理只有开头 ``` 的情况
  # 如果内容以 ``` 开头，但不是正常的代码块（即后面紧跟的是 front matter 或标题等），则去除
  defp strip_opening_fence_if_wrapper(text) do
    # 去除开头的 ``` 行
    without_opening = String.replace(text, ~r/^```[a-zA-Z]*\s*\n/, "")

    # 检查去除后的内容是否以 front matter (---) 或标题 (#) 开头
    # 这表明 ``` 是错误添加的包装
    if String.match?(without_opening, ~r/^(---|#|\*\*|<[A-Z])/) do
      # 如果内容中有未闭合的 ``` 在末尾，也去除它
      without_opening
      |> String.replace(~r/\n```\s*$/, "")
      |> String.trim()
    else
      # 保持原样，这可能是正常的代码块
      text
    end
  end
end
