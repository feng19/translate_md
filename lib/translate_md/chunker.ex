defmodule TranslateMd.Chunker do
  @moduledoc """
  Markdown 智能分块模块。
  将大型 Markdown 文件分割成多个较小的块，同时保持段落完整性。

  注意：代码块等不可翻译内容已由 Preserver 模块预先处理并替换为占位符，
  因此本模块无需处理代码块的保留逻辑。
  """

  @doc """
  将 Markdown 内容分割成多个块。

  分割策略：
  1. 按空行分割成段落
  2. 使用贪心算法将段落组合成块，每块不超过指定大小
  3. 返回带索引的块列表，用于并发翻译后的排序

  ## 参数
    - content: Markdown 文件内容（应已由 Preserver 预处理）
    - chunk_size: 每块的最大字符数

  ## 返回值
    - 带索引的块列表 `[{index, chunk_content}, ...]`

  ## 示例
      iex> TranslateMd.Chunker.split("# Title\\n\\nPara 1\\n\\nPara 2", 1000)
      [{0, "# Title\\n\\nPara 1\\n\\nPara 2"}]
  """
  @spec split(String.t(), pos_integer()) :: [{non_neg_integer(), String.t()}]
  def split(content, chunk_size) when is_binary(content) and chunk_size > 0 do
    content
    |> split_into_paragraphs()
    |> group_paragraphs(chunk_size)
    |> Enum.with_index(fn chunk, index -> {index, chunk} end)
  end

  @doc """
  将内容按空行分割成段落。
  """
  @spec split_into_paragraphs(String.t()) :: [String.t()]
  def split_into_paragraphs(content) do
    content
    |> String.split(~r/\n\n+/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  @doc """
  使用贪心算法将段落组合成块。
  每个块的大小不超过 max_size。
  """
  @spec group_paragraphs([String.t()], pos_integer()) :: [String.t()]
  def group_paragraphs(paragraphs, max_size) do
    paragraphs
    |> Enum.reduce({[], ""}, fn para, {chunks, current_chunk} ->
      para_size = String.length(para)
      current_size = String.length(current_chunk)

      cond do
        # 单个段落超过 max_size，单独作为一个块
        para_size > max_size and current_chunk == "" ->
          {[para | chunks], ""}

        # 单个段落超过 max_size，保存当前块，段落单独作为新块
        para_size > max_size ->
          {[para, current_chunk | chunks], ""}

        # 添加后不超过限制，合并到当前块
        current_size + para_size + 2 <= max_size ->
          new_chunk =
            if current_chunk == "" do
              para
            else
              current_chunk <> "\n\n" <> para
            end

          {chunks, new_chunk}

        # 添加后超过限制，保存当前块，开始新块
        true ->
          {[current_chunk | chunks], para}
      end
    end)
    |> case do
      {chunks, ""} -> chunks
      {chunks, current_chunk} -> [current_chunk | chunks]
    end
    |> Enum.reverse()
  end

  @doc """
  获取分块统计信息。
  """
  @spec stats(String.t(), pos_integer()) :: map()
  def stats(content, chunk_size) do
    chunks = split(content, chunk_size)

    %{
      total_chars: String.length(content),
      chunk_count: length(chunks),
      chunk_sizes: Enum.map(chunks, fn {_, chunk} -> String.length(chunk) end),
      avg_chunk_size:
        if(length(chunks) > 0,
          do:
            div(
              Enum.sum(Enum.map(chunks, fn {_, chunk} -> String.length(chunk) end)),
              length(chunks)
            ),
          else: 0
        )
    }
  end
end
