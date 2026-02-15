# TranslateMd

使用 Ollama 翻译 Markdown 文档的 Elixir 命令行工具。

## 特性

- 🚀 **并发翻译** - 利用 Elixir 的并发特性，同时翻译多个文本块
- 📝 **保持格式** - 保持 Markdown 格式、代码块、链接和技术术语
- 🔒 **智能保留** - 自动识别并保留不需要翻译的内容（代码、URL、base64图片等）
- ⚙️ **可配置** - 支持自定义模型、并发数、块大小等参数
- 📊 **进度显示** - 实时显示翻译进度

## 安装

### 前置条件

- Elixir 1.15+
- [Ollama](https://ollama.ai/) 已安装并运行
- 已拉取翻译模型（默认使用 `translategemma`）

### 编译

```bash
cd translate_md

# 安装依赖
mix deps.get

# 编译为可执行文件
mix escript.build
```

## 使用方法

### 基本使用

```bash
# 翻译单个文件（输出到 README_zh.md）
./translate_md README.md

# 指定输出文件
./translate_md -o 输出.md 文档.md
```

### 配置选项

```bash
用法:
  translate_md [选项] <输入文件.md>

选项:
  -h, --help              显示帮助信息
  -m, --model MODEL       指定 Ollama 模型 (默认: translategemma)
  -o, --output FILE       指定输出文件名 (默认: 输入文件名_zh.md)
  -p, --prompt PROMPT     自定义 System Prompt
  -s, --chunk-size SIZE   每次翻译的字符数 (默认: 1200)
  -t, --temperature TEMP  模型温度 (默认: 0.3)
  -c, --concurrency NUM   最大并发数 (默认: 16)
  -d, --debug             启用调试模式
  --show-default-prompt   显示默认的 System Prompt
```

### 示例

```bash
# 使用 gemma2 模型
./translate_md -m gemma2 README.md

# 使用 8 个并发加速翻译
./translate_md -c 8 large-doc.md

# 自定义翻译提示
./translate_md -p "翻译为简体中文，保持专业术语不翻译" input.md

# 调试模式查看详细信息
./translate_md --debug input.md

# 组合多个选项
./translate_md -m gemma2 -c 8 -s 5000 -o output_zh.md input.md
```

## 智能内容保留

翻译过程中会自动识别并保留以下不需要翻译的内容：

| 内容类型 | 示例 | 说明 |
|---------|------|------|
| Front Matter | `---\ntitle: ...\n---` | YAML/TOML 元数据 |
| 代码块 | ` ```python...``` ` | 保持代码完整不翻译 |
| 行内代码 | `` `npm install` `` | 变量名、命令等 |
| Base64 图片 | `![](data:image/png;base64,...)` | 内嵌图片数据 |
| 链接 URL | `[文本](https://...)` | 仅翻译文本，保留 URL |
| 图片路径 | `![描述](./image.png)` | 仅翻译描述，保留路径 |
| 引用式链接 | `[id]: https://...` | 链接定义整行保留 |
| 数学公式 | `$E=mc^2$` / `$$...$$` | LaTeX 公式 |
| 自动链接 | `<https://example.com>` | 尖括号包裹的 URL |

这些内容会在翻译前被提取并替换为占位符，翻译完成后自动还原，确保格式和链接的完整性。

## 并发原理

TranslateMd 使用 Elixir 的 `Task.async_stream` 实现并发翻译：

1. **内容保留** - 提取代码块、URL、图片等不需要翻译的内容
2. **分块** - 将大文件按段落分割成多个块，每块不超过指定大小
3. **并发请求** - 同时向 Ollama API 发送多个翻译请求
4. **有序合并** - 使用索引保证翻译结果按原始顺序合并
5. **内容还原** - 将占位符替换回原始内容

```
┌─────────────────────────────────────────────────────────────┐
│                       输入文件                               │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Chunker 分块                              │
│         [Chunk 0] [Chunk 1] [Chunk 2] [Chunk 3]             │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────┬───────┼───────┬───────┐
              ▼       ▼       ▼       ▼       │
           ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐    │ 并发
           │Task │ │Task │ │Task │ │Task │    │ max_concurrency=4
           │  0  │ │  1  │ │  2  │ │  3  │    │
           └──┬──┘ └──┬──┘ └──┬──┘ └──┬──┘    │
              │       │       │       │       │
              ▼       ▼       ▼       ▼       ▼
         ┌────────────────────────────────────────┐
         │            Ollama API                  │
         └────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              按索引排序并合并结果                              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                       输出文件                               │
└─────────────────────────────────────────────────────────────┘
```

## 性能对比

| 场景 | Bash 脚本（串行） | Elixir（并发 4） | 提升 |
|------|-------------------|------------------|------|
| 10 个 chunks | ~50 秒 | ~15 秒 | 3.3x |
| 20 个 chunks | ~100 秒 | ~28 秒 | 3.6x |

*注：实际性能取决于 Ollama 服务和模型响应速度*

## 作为库使用

也可以在 Elixir 项目中作为库使用：

```elixir
# 简单用法
TranslateMd.translate("README.md")

# 带选项
TranslateMd.translate("README.md",
  output: "README_zh.md",
  model: "gemma2",
  concurrency: 8
)

# 完整配置
config = TranslateMd.Config.new(
  input_file: "README.md",
  output_file: "README_zh.md",
  model: "gemma2",
  concurrency: 8,
  chunk_size: 5000
)

TranslateMd.Translator.translate_file(config)
```

## 开发

```bash
# 运行测试
mix test

# 格式化代码
mix format

# 在 IEx 中测试
iex -S mix
```

## 许可证

MIT License
