defmodule TranslateMd.Preserver do
  @moduledoc """
  处理 Markdown 中不需要翻译的内容。
  提取这些内容并替换为占位符，翻译后再还原。

  支持的内容类型：
  1. Front Matter (YAML/TOML 元数据)
  2. 代码块 (```...```) - 支持嵌套代码块
  3. 数学公式块 ($$...$$)
  4. Base64 图片 (Markdown 和 HTML 格式)
  5. 引用式链接定义 ([id]: url "title")
  6. HTML 标签 (保留属性，翻译内容)
  7. 行内代码 (`...`)
  8. 链接 URL (保留 URL，翻译文本)
  9. 图片路径 (保留路径，翻译 alt 文本)
  10. 行内数学公式 ($...$)
  """

  # 占位符格式
  @placeholder_prefix "{{__PRESERVE_"
  @placeholder_suffix "__}}"

  # 正则表达式定义
  # Front Matter (文件开头的 YAML/TOML)
  @front_matter_regex ~r/\A(---\n[\s\S]*?\n---\n)/

  # 数学公式块
  @math_block_regex ~r/(\$\$[\s\S]*?\$\$)/

  # Base64 图片 - Markdown 格式
  @base64_md_img_regex ~r/(!\[[^\]]*\]\(data:image\/[^;]+;base64,[A-Za-z0-9+\/=]+\))/

  # Base64 图片 - HTML 格式
  @base64_html_img_regex ~r/(<img[^>]*src=["']data:image\/[^;]+;base64,[A-Za-z0-9+\/=]+["'][^>]*\/?>)/i

  # 引用式链接定义
  # 格式: [id]: URL "optional title" 或 'title' 或 (title)
  @ref_link_def_regex ~r/(^\[([^\]]+)\]:\s+\S+(?:\s+["'(][^"')]*["')])?$)/m

  # HTML 标签 (自闭合或成对标签)
  @html_tag_regex ~r/(<[a-zA-Z][^>]*(?:\/>|>[\s\S]*?<\/[a-zA-Z]+>))/

  # 行内代码
  @inline_code_regex ~r/(`[^`\n]+`)/

  # 自动链接 <https://...>
  @auto_link_regex ~r/(<https?:\/\/[^>]+>)/

  # 行内数学公式 (单个 $)
  # 注意：需要避免匹配货币符号，所以要求 $ 后面紧跟非空白字符
  @math_inline_regex ~r/(\$[^\$\s][^\$]*[^\$\s]\$|\$[^\$\s]\$)/

  @type placeholders :: %{String.t() => map()}

  @doc """
  提取所有不可翻译内容，替换为占位符。
  返回处理后的内容和占位符映射表。

  ## 参数
    - content: 原始 Markdown 内容

  ## 返回值
    - `{processed_content, placeholders}` 元组

  ## 示例
      iex> {content, placeholders} = Preserver.preserve("Hello `code` world")
      iex> String.contains?(content, "{{__PRESERVE_")
      true
      iex> map_size(placeholders) > 0
      true
  """
  @spec preserve(String.t()) :: {String.t(), placeholders()}
  def preserve(content) when is_binary(content) do
    # 按照正确的顺序处理各类内容
    # 顺序很重要：先处理可能包含其他语法的块级元素
    {content, %{}}
    |> preserve_type(:front_matter, @front_matter_regex)
    |> preserve_code_blocks()
    |> preserve_type(:math_block, @math_block_regex)
    |> preserve_type(:base64_md_img, @base64_md_img_regex)
    |> preserve_type(:base64_html_img, @base64_html_img_regex)
    |> preserve_type(:ref_link_def, @ref_link_def_regex)
    |> preserve_type(:html_tag, @html_tag_regex)
    |> preserve_type(:inline_code, @inline_code_regex)
    |> preserve_type(:auto_link, @auto_link_regex)
    |> preserve_link_urls()
    |> preserve_image_paths()
    |> preserve_type(:math_inline, @math_inline_regex)
  end

  @doc """
  将占位符还原为原始内容。

  ## 参数
    - content: 包含占位符的内容
    - placeholders: 占位符到原始内容的映射

  ## 返回值
    - 还原后的原始内容

  ## 示例
      iex> Preserver.restore("Hello {{__PRESERVE_CODE_0__}} world", %{"{{__PRESERVE_CODE_0__}}" => "`code`"})
      "Hello `code` world"
  """
  @spec restore(String.t(), placeholders()) :: String.t()
  def restore(content, placeholders) when is_binary(content) and is_map(placeholders) do
    # 先清理 LLM 可能在代码块占位符周围添加的多余代码围栏
    content = strip_llm_added_fences(content, placeholders)

    # 按照占位符的编号从大到小还原，避免部分匹配问题
    placeholders
    |> Enum.sort_by(fn {_key, info} -> -info.index end)
    |> Enum.reduce(content, fn {placeholder, info}, acc ->
      String.replace(acc, placeholder, info.original_content)
    end)
  end

  @doc """
  获取保留内容的统计信息。
  """
  @spec stats(placeholders()) :: map()
  def stats(placeholders) when is_map(placeholders) do
    placeholders
    |> Enum.group_by(fn {_key, info} -> info.type end)
    |> Enum.map(fn {type, items} -> {type, length(items)} end)
    |> Map.new()
  end

  # ============================================
  # 私有函数
  # ============================================

  # 清理 LLM 在翻译过程中添加的多余代码围栏
  #
  # 原理：所有真正的代码块在 preserve 阶段已被提取为占位符，
  # 因此翻译后的内容中不应存在任何 ``` 围栏。
  # 如果存在，一定是 LLM 错误添加的，可以安全地全部移除。
  defp strip_llm_added_fences(content, placeholders) do
    has_code_blocks =
      Enum.any?(placeholders, fn {_key, info} -> info.type == "code_block" end)

    if has_code_blocks do
      content
      |> String.split("\n")
      |> Enum.map(fn line ->
        cond do
          # 独立的 ``` 行（可能带有语言标识和空白字符）-> 直接移除
          String.match?(line, ~r/^\s*```[a-zA-Z0-9]*\s*$/) ->
            nil

          # ``` 后面跟着占位符的行 -> 去掉 ``` 前缀，保留占位符
          String.match?(line, ~r/^\s*```[a-zA-Z0-9]*\s+.*__PRESERVE_/) ->
            String.replace(line, ~r/^\s*```[a-zA-Z0-9]*\s+/, "")

          true ->
            line
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n")
    else
      content
    end
  end

  # 特殊处理：代码块（支持嵌套）
  # 使用状态机方式解析，正确处理嵌套的代码块
  defp preserve_code_blocks({content, placeholders}) do
    code_blocks = extract_code_blocks(content)

    {new_content, new_placeholders} =
      code_blocks
      |> Enum.with_index(map_size(placeholders))
      |> Enum.reduce({content, placeholders}, fn {code_block, index},
                                                 {acc_content, acc_placeholders} ->
        placeholder = make_placeholder(:code_block, index)
        new_content = String.replace(acc_content, code_block, placeholder, global: false)
        info = %{type: "code_block", index: index, original_content: code_block}
        new_placeholders = Map.put(acc_placeholders, placeholder, info)
        {new_content, new_placeholders}
      end)

    {new_content, new_placeholders}
  end

  # 提取所有代码块，正确处理嵌套情况
  # 算法：逐行扫描，使用深度计数器跟踪嵌套
  defp extract_code_blocks(content) do
    lines = String.split(content, "\n")
    {blocks, _} = extract_blocks_recursive(lines, [], 0, [])
    Enum.reverse(blocks)
  end

  # 递归处理每一行
  # lines: 剩余行
  # current_block: 当前正在累积的代码块行（反序）
  # depth: 当前嵌套深度（0 表示不在代码块中）
  # blocks: 已完成的代码块列表（反序）
  defp extract_blocks_recursive([], [], 0, blocks) do
    # 处理完毕，没有未闭合的块
    {blocks, []}
  end

  defp extract_blocks_recursive([], current_block, _depth, blocks) when current_block != [] do
    # 有未闭合的代码块，作为一个块返回（容错）
    block_content = current_block |> Enum.reverse() |> Enum.join("\n")
    {[block_content | blocks], []}
  end

  defp extract_blocks_recursive([line | rest], [], 0, blocks) do
    # 不在代码块中
    if code_block_fence?(line) do
      # 开始新的代码块
      extract_blocks_recursive(rest, [line], 1, blocks)
    else
      # 普通行，跳过
      extract_blocks_recursive(rest, [], 0, blocks)
    end
  end

  defp extract_blocks_recursive([line | rest], current_block, depth, blocks) when depth > 0 do
    # 在代码块中
    new_block = [line | current_block]

    cond do
      code_block_start_fence?(line) ->
        # 嵌套的代码块开始，深度 +1
        extract_blocks_recursive(rest, new_block, depth + 1, blocks)

      code_block_end_fence?(line) ->
        new_depth = depth - 1

        if new_depth == 0 do
          # 代码块结束
          block_content = new_block |> Enum.reverse() |> Enum.join("\n")
          extract_blocks_recursive(rest, [], 0, [block_content | blocks])
        else
          # 嵌套代码块结束，继续
          extract_blocks_recursive(rest, new_block, new_depth, blocks)
        end

      true ->
        # 普通行
        extract_blocks_recursive(rest, new_block, depth, blocks)
    end
  end

  # 检查是否是代码块围栏（开始或结束）
  defp code_block_fence?(line) do
    String.match?(line, ~r/^```/)
  end

  # 检查是否是代码块开始围栏（``` 后面可能有语言标识）
  defp code_block_start_fence?(line) do
    # 开始围栏：``` 后面有语言标识或其他字符（非空白结尾）
    # 或者就是单独的 ```（也可以是开始）
    # 为了区分开始和结束，我们认为：
    # - ```xxx 是开始（有语言标识）
    # - ``` 单独一行，需要根据上下文判断
    # 简化处理：如果 ``` 后面有非空白字符，则是开始
    String.match?(line, ~r/^```\S/)
  end

  # 检查是否是代码块结束围栏（只有 ```）
  defp code_block_end_fence?(line) do
    String.match?(line, ~r/^```\s*$/)
  end

  # 通用的保留函数：使用正则匹配并替换为占位符
  defp preserve_type({content, placeholders}, type, regex) do
    matches = Regex.scan(regex, content) |> Enum.map(&List.first/1)

    type_str = Atom.to_string(type)

    {new_content, new_placeholders} =
      matches
      |> Enum.with_index(map_size(placeholders))
      |> Enum.reduce({content, placeholders}, fn {match, index},
                                                 {acc_content, acc_placeholders} ->
        placeholder = make_placeholder(type, index)
        new_content = String.replace(acc_content, match, placeholder, global: false)
        info = %{type: type_str, index: index, original_content: match}
        new_placeholders = Map.put(acc_placeholders, placeholder, info)
        {new_content, new_placeholders}
      end)

    {new_content, new_placeholders}
  end

  # 特殊处理：链接 URL
  # 保留 URL 部分，但让链接文本可以被翻译
  # [text](url) -> [text]({{__PRESERVE_URL_X__}})
  defp preserve_link_urls({content, placeholders}) do
    # 匹配 [text](url) 或 [text](url "title")
    # 使用负向后查找 (?<!!) 排除图片语法 ![alt](url)
    regex = ~r/(?<!!)\[([^\]]+)\]\(([^)\s]+)(?:\s+"[^"]*")?\)/

    matches = Regex.scan(regex, content)

    {new_content, new_placeholders} =
      matches
      |> Enum.with_index(map_size(placeholders))
      |> Enum.reduce({content, placeholders}, fn {[full_match, text, url], index},
                                                 {acc_content, acc_placeholders} ->
        placeholder = make_placeholder(:link_url, index)
        # 重建链接，只替换 URL 部分
        replacement = "[#{text}](#{placeholder})"
        new_content = String.replace(acc_content, full_match, replacement, global: false)
        info = %{type: "link_url", index: index, original_content: url}
        new_placeholders = Map.put(acc_placeholders, placeholder, info)
        {new_content, new_placeholders}
      end)

    {new_content, new_placeholders}
  end

  # 特殊处理：图片路径
  # 保留路径部分，但让 alt 文本可以被翻译
  # ![alt](path) -> ![alt]({{__PRESERVE_IMG_PATH_X__}})
  defp preserve_image_paths({content, placeholders}) do
    # 匹配 ![alt](path) 或 ![alt](path "title")，排除已处理的 base64 和占位符
    regex = ~r/!\[([^\]]*)\]\((?!data:)(?!{{__PRESERVE_)([^)\s]+)(?:\s+"[^"]*")?\)/

    matches = Regex.scan(regex, content)

    {new_content, new_placeholders} =
      matches
      |> Enum.with_index(map_size(placeholders))
      |> Enum.reduce({content, placeholders}, fn {[full_match, alt, path], index},
                                                 {acc_content, acc_placeholders} ->
        placeholder = make_placeholder(:img_path, index)
        # 重建图片，只替换路径部分
        replacement = "![#{alt}](#{placeholder})"
        new_content = String.replace(acc_content, full_match, replacement, global: false)
        info = %{type: "img_path", index: index, original_content: path}
        new_placeholders = Map.put(acc_placeholders, placeholder, info)
        {new_content, new_placeholders}
      end)

    {new_content, new_placeholders}
  end

  # 生成占位符
  defp make_placeholder(type, index) do
    type_str = type |> Atom.to_string() |> String.upcase()
    "#{@placeholder_prefix}#{type_str}_#{index}#{@placeholder_suffix}"
  end

end
