defmodule TranslateMd.PreserverTest do
  use ExUnit.Case, async: true
  alias TranslateMd.Preserver

  describe "preserve/1 and restore/2" do
    test "preserves front matter" do
      content = """
      ---
      title: My Post
      date: 2024-01-01
      tags: [tech, ai]
      ---

      # Hello World

      Some content here.
      """

      {preserved, placeholders} = Preserver.preserve(content)

      # Front matter should be replaced with placeholder
      assert String.contains?(preserved, "{{__PRESERVE_FRONT_MATTER_")
      refute String.contains?(preserved, "title: My Post")

      # Restore should bring back the original content
      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "title: My Post")
      assert String.contains?(restored, "date: 2024-01-01")
    end

    test "preserves code blocks" do
      content = """
      # Example

      ```python
      def hello():
          print("world")

          return True
      ```

      Some text.
      """

      {preserved, placeholders} = Preserver.preserve(content)

      assert String.contains?(preserved, "{{__PRESERVE_CODE_BLOCK_")
      refute String.contains?(preserved, "def hello():")

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "def hello():")
      assert String.contains?(restored, "print(\"world\")")
    end

    test "preserves inline code" do
      content = "Use `npm install` to install and `npm run` to execute."

      {preserved, placeholders} = Preserver.preserve(content)

      assert String.contains?(preserved, "{{__PRESERVE_INLINE_CODE_")
      refute String.contains?(preserved, "`npm install`")

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "`npm install`")
      assert String.contains?(restored, "`npm run`")
    end

    test "preserves base64 images - markdown format" do
      content = """
      # Image Test

      ![test image](data:image/png;base64,dGVzdA==)

      Some text.
      """

      {preserved, placeholders} = Preserver.preserve(content)

      assert String.contains?(preserved, "{{__PRESERVE_BASE64_MD_IMG_")
      refute String.contains?(preserved, "dGVzdA")

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "data:image/png;base64,dGVzdA")
    end

    test "preserves base64 images - html format" do
      content = """
      # Image Test

      <img src="data:image/png;base64,dGVzdA==" alt="test">

      Some text.
      """

      {preserved, placeholders} = Preserver.preserve(content)

      assert String.contains?(preserved, "{{__PRESERVE_BASE64_HTML_IMG_")
      refute String.contains?(preserved, "dGVzdA")

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "<img src=\"data:image/png;base64,dGVzdA")
    end

    test "preserves reference-style link definitions" do
      content = """
      # Links

      Check out [Google][google] and [GitHub][gh].

      [google]: https://google.com "Google Search"
      [gh]: https://github.com
      """

      {preserved, placeholders} = Preserver.preserve(content)

      assert String.contains?(preserved, "{{__PRESERVE_REF_LINK_DEF_")
      refute String.contains?(preserved, "[google]: https://google.com")

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "[google]: https://google.com \"Google Search\"")
      assert String.contains?(restored, "[gh]: https://github.com")
    end

    test "preserves math blocks" do
      content = """
      # Math

      The equation is:

      $$
      E = mc^2
      $$

      And inline $x^2$.
      """

      {preserved, placeholders} = Preserver.preserve(content)

      assert String.contains?(preserved, "{{__PRESERVE_MATH_BLOCK_")
      refute String.contains?(preserved, "$$\nE = mc^2\n$$")

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "E = mc^2")
    end

    test "preserves inline math" do
      content = "The formula $E = mc^2$ is famous. Also $x^2 + y^2 = z^2$ is known."

      {preserved, placeholders} = Preserver.preserve(content)

      assert String.contains?(preserved, "{{__PRESERVE_MATH_INLINE_")
      refute String.contains?(preserved, "$E = mc^2$")

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "$E = mc^2$")
      assert String.contains?(restored, "$x^2 + y^2 = z^2$")
    end

    test "preserves link URLs but keeps text for translation" do
      content = "Visit [our website](https://example.com/path?query=1) for more info."

      {preserved, placeholders} = Preserver.preserve(content)

      # The link text should remain for translation
      assert String.contains?(preserved, "our website")
      # The URL should be replaced
      assert String.contains?(preserved, "{{__PRESERVE_LINK_URL_")
      refute String.contains?(preserved, "https://example.com/path")

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "[our website](https://example.com/path?query=1)")
    end

    test "preserves image paths but keeps alt text for translation" do
      content = "Here is an image: ![beautiful sunset](./images/sunset.png)"

      {preserved, placeholders} = Preserver.preserve(content)

      # The alt text should remain for translation
      assert String.contains?(preserved, "beautiful sunset")
      # The path should be replaced
      assert String.contains?(preserved, "{{__PRESERVE_IMG_PATH_")
      refute String.contains?(preserved, "./images/sunset.png")

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "![beautiful sunset](./images/sunset.png)")
    end

    test "preserves auto links" do
      content = "Visit <https://example.com> for more information."

      {preserved, placeholders} = Preserver.preserve(content)

      assert String.contains?(preserved, "{{__PRESERVE_AUTO_LINK_")
      refute String.contains?(preserved, "<https://example.com>")

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "<https://example.com>")
    end

    test "handles content without preservable elements" do
      content = "This is a simple paragraph with no special elements."

      {preserved, placeholders} = Preserver.preserve(content)

      assert preserved == content
      assert placeholders == %{}
    end

    test "handles multiple elements of same type" do
      content = """
      Use `npm install` first, then `npm run build`, and finally `npm test`.
      """

      {preserved, placeholders} = Preserver.preserve(content)

      # Should have 3 inline code placeholders
      inline_code_count =
        placeholders
        |> Map.keys()
        |> Enum.count(&String.contains?(&1, "INLINE_CODE"))

      assert inline_code_count == 3

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "`npm install`")
      assert String.contains?(restored, "`npm run build`")
      assert String.contains?(restored, "`npm test`")
    end

    test "handles nested content correctly - code block with markdown inside" do
      content = """
      Example markdown:

      ```markdown
      # Title

      ![image](path.png)

      [link](https://example.com)
      ```

      End of example.
      """

      {preserved, placeholders} = Preserver.preserve(content)

      # The entire code block should be preserved, including the markdown inside
      assert String.contains?(preserved, "{{__PRESERVE_CODE_BLOCK_")

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "![image](path.png)")
      assert String.contains?(restored, "[link](https://example.com)")
    end

    test "handles mixed content types" do
      content = """
      ---
      title: Test
      ---

      # Hello

      Use `npm install` to install.

      ```javascript
      console.log("hello");
      ```

      Visit [our site](https://example.com).

      ![logo](./logo.png)

      The formula $E = mc^2$ is important.

      [ref]: https://reference.com
      """

      {preserved, placeholders} = Preserver.preserve(content)

      # All types should be preserved
      assert map_size(placeholders) > 0

      restored = Preserver.restore(preserved, placeholders)

      # All original content should be restored
      assert String.contains?(restored, "title: Test")
      assert String.contains?(restored, "`npm install`")
      assert String.contains?(restored, "console.log(\"hello\")")
      assert String.contains?(restored, "https://example.com")
      assert String.contains?(restored, "./logo.png")
      assert String.contains?(restored, "$E = mc^2$")
      assert String.contains?(restored, "[ref]: https://reference.com")
    end
  end

  describe "stats/1" do
    test "returns statistics about preserved content" do
      content = """
      Use `code1` and `code2`.

      ```python
      print("hello")
      ```

      Visit [link](https://example.com).
      """

      {_preserved, placeholders} = Preserver.preserve(content)
      stats = Preserver.stats(placeholders)

      assert is_map(stats)
      assert Map.get(stats, "inline_code") == 2
      assert Map.get(stats, "code_block") == 1
    end
  end

  describe "edge cases" do
    test "handles empty content" do
      {preserved, placeholders} = Preserver.preserve("")
      assert preserved == ""
      assert placeholders == %{}
    end

    test "handles content with only whitespace" do
      {preserved, placeholders} = Preserver.preserve("   \n\n   ")
      assert preserved == "   \n\n   "
      assert placeholders == %{}
    end

    test "handles single character inline code" do
      content = "The variable `x` is used."
      {preserved, placeholders} = Preserver.preserve(content)

      assert String.contains?(preserved, "{{__PRESERVE_INLINE_CODE_")

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "`x`")
    end

    test "handles URL with special characters" do
      content = "[link](https://example.com/path?a=1&b=2#section)"

      {preserved, placeholders} = Preserver.preserve(content)

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "https://example.com/path?a=1&b=2#section")
    end

    test "handles HTML self-closing tags" do
      content = "<img src=\"data:image/png;base64,ABC123\" />"

      {preserved, placeholders} = Preserver.preserve(content)

      assert String.contains?(preserved, "{{__PRESERVE_BASE64_HTML_IMG_")

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "data:image/png;base64,ABC123")
    end
  end

  describe "code block edge cases" do
    test "handles multiple identical code blocks" do
      content = """
      First block:

      ```python
      print("hello")
      ```

      Second block (same content):

      ```python
      print("hello")
      ```

      Third block (same content):

      ```python
      print("hello")
      ```
      """

      {preserved, placeholders} = Preserver.preserve(content)

      # Should have 3 separate placeholders
      code_block_count =
        placeholders
        |> Map.keys()
        |> Enum.count(&String.contains?(&1, "CODE_BLOCK"))

      assert code_block_count == 3

      restored = Preserver.restore(preserved, placeholders)
      # Count occurrences of the code block
      assert length(String.split(restored, "```python")) == 4
    end

    test "handles consecutive code blocks without text between" do
      content = """
      ```python
      print("first")
      ```
      ```javascript
      console.log("second");
      ```
      ```ruby
      puts "third"
      ```
      """

      {preserved, placeholders} = Preserver.preserve(content)

      code_block_count =
        placeholders
        |> Map.keys()
        |> Enum.count(&String.contains?(&1, "CODE_BLOCK"))

      assert code_block_count == 3

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "print(\"first\")")
      assert String.contains?(restored, "console.log(\"second\")")
      assert String.contains?(restored, "puts \"third\"")
    end

    test "handles code block with empty lines inside" do
      content = """
      ```python
      def hello():
          pass


      def world():
          pass
      ```
      """

      {preserved, placeholders} = Preserver.preserve(content)

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "def hello():")
      assert String.contains?(restored, "def world():")
      # Verify empty lines are preserved
      assert String.contains?(restored, "pass\n\n\ndef world")
    end

    test "handles code block with placeholder-like content inside" do
      content = """
      ```python
      # This looks like a placeholder: {{__PRESERVE_CODE_BLOCK_0__}}
      template = "{{__PRESERVE_INLINE_CODE_1__}}"
      ```
      """

      {preserved, placeholders} = Preserver.preserve(content)

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "{{__PRESERVE_CODE_BLOCK_0__}}")
      assert String.contains?(restored, "{{__PRESERVE_INLINE_CODE_1__}}")
    end

    test "handles code block with backticks inside" do
      content = """
      Here is some code:

      ```markdown
      Use `inline code` in markdown.

      Or use code blocks:

      ```python
      print("nested")
      ```
      ```
      """

      {preserved, placeholders} = Preserver.preserve(content)

      # The outer code block should be preserved as one unit
      code_block_count =
        placeholders
        |> Map.keys()
        |> Enum.count(&String.contains?(&1, "CODE_BLOCK"))

      # Should capture the outer block
      assert code_block_count >= 1

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "Use `inline code` in markdown")
    end

    test "handles code block with language identifier containing special chars" do
      content = """
      ```c++
      int main() { return 0; }
      ```

      ```c#
      class Program { }
      ```

      ```objective-c
      @interface MyClass @end
      ```
      """

      {preserved, placeholders} = Preserver.preserve(content)

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "int main()")
      assert String.contains?(restored, "class Program")
      assert String.contains?(restored, "@interface MyClass")
    end

    test "handles code block at the very end without trailing newline" do
      content = "Some text\n\n```python\nprint('end')\n```"

      {preserved, placeholders} = Preserver.preserve(content)

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "print('end')")
    end

    test "handles code block at the very beginning" do
      content = """
      ```python
      print('start')
      ```

      Some text after.
      """

      {preserved, placeholders} = Preserver.preserve(content)

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "print('start')")
    end

    test "handles inline code with backticks inside using double backticks" do
      content = "Use `` `backticks` `` to show literal backticks."

      {preserved, placeholders} = Preserver.preserve(content)

      restored = Preserver.restore(preserved, placeholders)
      # The double backtick syntax should be preserved
      assert String.contains?(restored, "``") or String.contains?(restored, "`backticks`")
    end

    test "handles multiple inline codes with same content" do
      content = "Use `npm` here and `npm` there and `npm` everywhere."

      {preserved, placeholders} = Preserver.preserve(content)

      inline_code_count =
        placeholders
        |> Map.keys()
        |> Enum.count(&String.contains?(&1, "INLINE_CODE"))

      assert inline_code_count == 3

      restored = Preserver.restore(preserved, placeholders)
      assert length(String.split(restored, "`npm`")) == 4
    end

    test "handles code block with only whitespace content" do
      content = """
      ```

      ```
      """

      {preserved, placeholders} = Preserver.preserve(content)

      code_block_count =
        placeholders
        |> Map.keys()
        |> Enum.count(&String.contains?(&1, "CODE_BLOCK"))

      assert code_block_count == 1

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "```")
    end

    test "handles code block with very long single line" do
      long_line = String.duplicate("x", 1000)

      content = """
      ```
      #{long_line}
      ```
      """

      {preserved, placeholders} = Preserver.preserve(content)

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, long_line)
    end

    test "handles mixed code blocks and inline code" do
      content = """
      Use `npm install` to install.

      ```bash
      npm install
      npm run build
      ```

      Then run `npm start` to start.

      ```javascript
      const x = `template literal`;
      ```

      Finally use `npm test`.
      """

      {preserved, placeholders} = Preserver.preserve(content)

      code_block_count =
        placeholders
        |> Map.keys()
        |> Enum.count(&String.contains?(&1, "CODE_BLOCK"))

      inline_code_count =
        placeholders
        |> Map.keys()
        |> Enum.count(&String.contains?(&1, "INLINE_CODE"))

      assert code_block_count == 2
      assert inline_code_count == 3

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "`npm install`")
      assert String.contains?(restored, "`npm start`")
      assert String.contains?(restored, "`npm test`")
      assert String.contains?(restored, "npm run build")
      assert String.contains?(restored, "template literal")
    end

    test "preserves exact whitespace in code blocks" do
      content = """
      ```python
      def hello():
          if True:
              print("indented")
      ```
      """

      {preserved, placeholders} = Preserver.preserve(content)

      restored = Preserver.restore(preserved, placeholders)
      # Check that indentation is preserved
      assert String.contains?(restored, "    if True:")
      assert String.contains?(restored, "        print")
    end

    test "handles code block with Windows line endings" do
      content = "```python\r\nprint('hello')\r\n```"

      {preserved, placeholders} = Preserver.preserve(content)

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "print('hello')")
    end

    test "handles code block with tabs" do
      content = """
      ```go
      func main() {
      \tif true {
      \t\tfmt.Println("tabbed")
      \t}
      }
      ```
      """

      {preserved, placeholders} = Preserver.preserve(content)

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "\t")
      assert String.contains?(restored, "fmt.Println")
    end

    test "handles code block with unicode characters" do
      content = """
      ```python
      # 这是中文注释
      print("你好世界")
      emoji = "🎉🚀"
      ```
      """

      {preserved, placeholders} = Preserver.preserve(content)

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "这是中文注释")
      assert String.contains?(restored, "你好世界")
      assert String.contains?(restored, "🎉🚀")
    end

    test "handles code block with regex special characters" do
      content = """
      ```javascript
      const regex = /\\d+\\.\\d+/g;
      const str = "price: $100.50";
      str.match(regex);
      ```
      """

      {preserved, placeholders} = Preserver.preserve(content)

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "/\\d+\\.\\d+/g")
      assert String.contains?(restored, "$100.50")
    end

    test "handles code block with dollar signs that look like math" do
      content = """
      ```bash
      echo $HOME
      price="$100"
      total=$((price * 2))
      ```

      The formula $E = mc^2$ is different.
      """

      {preserved, placeholders} = Preserver.preserve(content)

      # Code block should be preserved separately from math
      code_block_count =
        placeholders
        |> Map.keys()
        |> Enum.count(&String.contains?(&1, "CODE_BLOCK"))

      math_count =
        placeholders
        |> Map.keys()
        |> Enum.count(&String.contains?(&1, "MATH"))

      assert code_block_count == 1
      assert math_count == 1

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "echo $HOME")
      assert String.contains?(restored, "$E = mc^2$")
    end

    test "handles inline code adjacent to text without space" do
      content = "The`code`is adjacent to text."

      {preserved, placeholders} = Preserver.preserve(content)

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "`code`")
    end

    test "handles code block with triple backticks in string" do
      content = """
      ```python
      doc = \"\"\"
      This is a docstring with ``` inside
      \"\"\"
      ```
      """

      {preserved, placeholders} = Preserver.preserve(content)

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "docstring")
    end

    test "handles nested code blocks in markdown documentation" do
      # This is the real-world case from SKILL.md
      content = """
      ## Task Structure

      ```markdown
      ### Task N: [Component Name]

      **Files:**
      - Create: `exact/path/to/file.py`

      **Step 1: Write the failing test**

      ```python
      def test_specific_behavior():
          result = function(input)
          assert result == expected
      ```

      **Step 2: Run test**

      Run: `pytest tests/path/test.py::test_name -v`
      ```
      """

      {preserved, placeholders} = Preserver.preserve(content)

      # Should have exactly 1 code block (the outer markdown block)
      code_block_count =
        placeholders
        |> Map.keys()
        |> Enum.count(&String.contains?(&1, "CODE_BLOCK"))

      assert code_block_count == 1

      restored = Preserver.restore(preserved, placeholders)

      # The nested python code block should be preserved inside
      assert String.contains?(restored, "```python")
      assert String.contains?(restored, "def test_specific_behavior():")
      assert String.contains?(restored, "```markdown")
    end

    test "handles deeply nested code blocks" do
      content = """
      # Documentation

      Here's how to write documentation:

      ```markdown
      # Example Doc

      Show code like this:

      ```python
      def hello():
          print("world")
      ```

      And bash:

      ```bash
      echo "hello"
      ```
      ```

      End of documentation.
      """

      {preserved, placeholders} = Preserver.preserve(content)

      # Should preserve the outer markdown block as one unit
      code_block_count =
        placeholders
        |> Map.keys()
        |> Enum.count(&String.contains?(&1, "CODE_BLOCK"))

      assert code_block_count == 1

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "```python")
      assert String.contains?(restored, "```bash")
      assert String.contains?(restored, "def hello():")
    end
  end

  describe "restore handles LLM-added code fences around placeholders" do
    test "removes LLM-added code fences wrapping a code block placeholder" do
      # Original content has code blocks without language identifiers
      content = """
      # test

      hello

      I'm fine

      ```
      {
        content: "welcome"
      }
      ```

      related step fields

      ```
      {
       "help": "ask",
      }
      ```
      """

      {preserved, placeholders} = Preserver.preserve(content)

      # Verify code blocks were extracted
      code_block_count =
        placeholders
        |> Map.keys()
        |> Enum.count(&String.contains?(&1, "CODE_BLOCK"))

      assert code_block_count == 2

      # Simulate LLM wrapping placeholders in code fences (this is what LLMs do)
      # The LLM sees the placeholder and thinks it should be in a code block
      translated =
        Regex.replace(
          ~r/({{__PRESERVE_CODE_BLOCK_\d+__}})/,
          preserved,
          "```\n\\1\n```"
        )

      restored = Preserver.restore(translated, placeholders)

      # The restored content should NOT have doubled ``` fences
      refute String.contains?(restored, "```\n```"), "Found doubled code fences in restored content"

      # The code blocks should be properly restored
      assert String.contains?(restored, "content: \"welcome\"")
      assert String.contains?(restored, "\"help\": \"ask\"")
    end

    test "removes LLM-added code fences with language on wrapper" do
      content = "Some text\n\n```\n{\"key\": \"value\"}\n```\n\nMore text"

      {preserved, placeholders} = Preserver.preserve(content)

      # LLM wraps placeholder with ```json
      translated =
        Regex.replace(
          ~r/({{__PRESERVE_CODE_BLOCK_\d+__}})/,
          preserved,
          "```json\n\\1\n```"
        )

      restored = Preserver.restore(translated, placeholders)

      refute String.contains?(restored, "```json\n```"), "Found LLM wrapper fences in restored content"
      assert String.contains?(restored, "{\"key\": \"value\"}")
    end

    test "does not affect non-code-block placeholders wrapped in fences" do
      # Inline code should not be affected by code fence stripping
      content = "Use `npm install` to install."

      {preserved, placeholders} = Preserver.preserve(content)

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "`npm install`")
    end

    test "handles full translation scenario with code blocks without language identifiers" do
      # This is the exact scenario from the bug report
      original = "# test\n\nhello\n\nI'm fine\n\n```\n{\n  content: \"welcome\"\n}\n```\n\nrelated step fields\n\n```\n{\n \"help\": \"ask\",\n}\n```"

      {preserved, placeholders} = Preserver.preserve(original)

      # Simulate what the LLM returns: translated text with placeholders wrapped in code fences
      translated_with_llm_fences =
        preserved
        |> String.replace("# test", "# 测试")
        |> String.replace("hello", "你好")
        |> String.replace("I'm fine", "我很好")
        |> String.replace("related step fields", "相关步骤字段")
        |> then(fn text ->
          Regex.replace(
            ~r/({{__PRESERVE_CODE_BLOCK_\d+__}})/,
            text,
            "```\n\\1\n```"
          )
        end)

      restored = Preserver.restore(translated_with_llm_fences, placeholders)

      # Should have proper code blocks, not doubled fences
      refute String.contains?(restored, "```\n```"), "Found doubled code fences"
      assert String.contains?(restored, "# 测试")
      assert String.contains?(restored, "你好")
      assert String.contains?(restored, "我很好")
      assert String.contains?(restored, "相关步骤字段")
      assert String.contains?(restored, "content: \"welcome\"")
      assert String.contains?(restored, "\"help\": \"ask\"")
    end

    test "handles real LLM output with stray code fences (pattern from actual debug log)" do
      # This matches the exact real-world LLM output pattern observed in production
      original = "# test\n\nhello\n\nI'm fine\n\n```\n{\n  content: \"welcome\"\n}\n```\n\nrelated step fields\n\n```\n{\n \"help\": \"ask\",\n}\n```"

      {_preserved, placeholders} = Preserver.preserve(original)

      # Get the actual placeholder keys
      cb_keys =
        placeholders
        |> Enum.filter(fn {_k, v} -> v.type == "code_block" end)
        |> Enum.sort_by(fn {_k, v} -> v.index end)
        |> Enum.map(fn {k, _v} -> k end)

      [cb0, cb1] = cb_keys

      # Simulate the exact LLM output pattern from the debug log:
      # - ``` on its own line before first placeholder
      # - ``` with spaces on same line as second placeholder
      llm_output =
        "# 测试\n\n你好\n\n我很好\n\n```\n#{cb0}\n\n相关步骤字段\n\n```                  #{cb1}"

      restored = Preserver.restore(llm_output, placeholders)

      refute String.contains?(restored, "```\n```"), "Found doubled code fences"
      refute Regex.match?(~r/```\s+```/, restored), "Found stray code fences"
      assert String.contains?(restored, "# 测试")
      assert String.contains?(restored, "你好")
      assert String.contains?(restored, "我很好")
      assert String.contains?(restored, "相关步骤字段")
      assert String.contains?(restored, "content: \"welcome\"")
      assert String.contains?(restored, "\"help\": \"ask\"")
    end

    test "handles LLM adding only opening fence before placeholder" do
      content = "Text\n\n```\n{\"key\": \"value\"}\n```\n\nMore text"

      {preserved, placeholders} = Preserver.preserve(content)

      cb_key =
        placeholders
        |> Enum.filter(fn {_k, v} -> v.type == "code_block" end)
        |> Enum.map(fn {k, _v} -> k end)
        |> hd()

      # LLM adds only a ``` before the placeholder
      llm_output = String.replace(preserved, cb_key, "```\n#{cb_key}")

      restored = Preserver.restore(llm_output, placeholders)

      refute String.contains?(restored, "```\n```"), "Found doubled code fences"
      assert String.contains?(restored, "{\"key\": \"value\"}")
    end

    test "handles LLM adding only closing fence after placeholder" do
      content = "Text\n\n```\n{\"key\": \"value\"}\n```\n\nMore text"

      {preserved, placeholders} = Preserver.preserve(content)

      cb_key =
        placeholders
        |> Enum.filter(fn {_k, v} -> v.type == "code_block" end)
        |> Enum.map(fn {k, _v} -> k end)
        |> hd()

      # LLM adds only a ``` after the placeholder
      llm_output = String.replace(preserved, cb_key, "#{cb_key}\n```")

      restored = Preserver.restore(llm_output, placeholders)

      refute String.contains?(restored, "```\n```"), "Found doubled code fences"
      assert String.contains?(restored, "{\"key\": \"value\"}")
    end
  end

  describe "restore robustness" do
    test "handles translated content with modified whitespace around placeholders" do
      content = """
      # Title

      ```python
      print("hello")
      ```

      Some text.
      """

      {preserved, placeholders} = Preserver.preserve(content)

      # Simulate translation adding extra whitespace around placeholder
      translated = String.replace(preserved, ~r/(\{\{__PRESERVE_[^}]+__\}\})/, " \\1 ")

      restored = Preserver.restore(translated, placeholders)
      assert String.contains?(restored, "print(\"hello\")")
    end

    test "handles translated content with newlines around placeholders" do
      content = "Use `npm install` to install."

      {preserved, placeholders} = Preserver.preserve(content)

      # Simulate translation adding newlines
      translated = String.replace(preserved, ~r/(\{\{__PRESERVE_[^}]+__\}\})/, "\n\\1\n")

      restored = Preserver.restore(translated, placeholders)
      assert String.contains?(restored, "`npm install`")
    end

    test "restore works even if some placeholders are missing from content" do
      content = """
      Use `code1` and `code2`.
      """

      {preserved, placeholders} = Preserver.preserve(content)

      # Simulate translation removing one placeholder entirely
      # Find one placeholder and remove it
      [first_placeholder | _] = Map.keys(placeholders)
      modified = String.replace(preserved, first_placeholder, "")

      # Should not crash, should restore what's left
      restored = Preserver.restore(modified, placeholders)
      # At least one code should be restored
      assert String.contains?(restored, "`code")
    end

    test "handles placeholder at the very beginning of content" do
      content = "`code` starts the content."

      {preserved, placeholders} = Preserver.preserve(content)

      assert String.starts_with?(preserved, "{{__PRESERVE_")

      restored = Preserver.restore(preserved, placeholders)
      assert String.starts_with?(restored, "`code`")
    end

    test "handles placeholder at the very end of content" do
      content = "Content ends with `code`"

      {preserved, placeholders} = Preserver.preserve(content)

      assert String.ends_with?(preserved, "__}}")

      restored = Preserver.restore(preserved, placeholders)
      assert String.ends_with?(restored, "`code`")
    end

    test "handles content that is only a code block" do
      content = """
      ```python
      print("only code")
      ```
      """

      {preserved, placeholders} = Preserver.preserve(content)

      restored = Preserver.restore(preserved, placeholders)
      assert String.contains?(restored, "print(\"only code\")")
    end

    test "handles content that is only inline code" do
      content = "`only_code`"

      {preserved, placeholders} = Preserver.preserve(content)

      restored = Preserver.restore(preserved, placeholders)
      assert restored == "`only_code`"
    end
  end

  describe "complex real-world scenarios" do
    test "handles documentation with multiple code examples" do
      content = """
      # Installation Guide

      ## Prerequisites

      Make sure you have `node` (version >= 16) and `npm` installed.

      ## Step 1: Clone the repository

      ```bash
      git clone https://github.com/example/repo.git
      cd repo
      ```

      ## Step 2: Install dependencies

      ```bash
      npm install
      ```

      ## Step 3: Configure

      Create a `.env` file:

      ```
      API_KEY=your_key_here
      DATABASE_URL=postgres://localhost/db
      ```

      ## Step 4: Run

      ```bash
      npm start
      ```

      Visit <http://localhost:3000> to see the app.

      For more info, see [the docs](https://docs.example.com).
      """

      {preserved, placeholders} = Preserver.preserve(content)

      # Verify counts
      code_block_count =
        placeholders
        |> Map.keys()
        |> Enum.count(&String.contains?(&1, "CODE_BLOCK"))

      inline_code_count =
        placeholders
        |> Map.keys()
        |> Enum.count(&String.contains?(&1, "INLINE_CODE"))

      assert code_block_count == 4
      # `node`, `npm`, `.env` = 3 inline codes
      assert inline_code_count >= 3

      restored = Preserver.restore(preserved, placeholders)

      # All code should be restored correctly
      assert String.contains?(restored, "git clone")
      assert String.contains?(restored, "npm install")
      assert String.contains?(restored, "API_KEY=your_key_here")
      assert String.contains?(restored, "npm start")
      assert String.contains?(restored, "`node`")
      assert String.contains?(restored, "`.env`")
    end

    test "handles API documentation with JSON examples" do
      content = """
      # API Reference

      ## POST /users

      Request body:

      ```json
      {
        "name": "John Doe",
        "email": "john@example.com",
        "age": 30
      }
      ```

      Response:

      ```json
      {
        "id": 123,
        "name": "John Doe",
        "created_at": "2024-01-01T00:00:00Z"
      }
      ```

      Use `curl` to test:

      ```bash
      curl -X POST https://api.example.com/users \\
        -H "Content-Type: application/json" \\
        -d '{"name": "John"}'
      ```
      """

      {preserved, placeholders} = Preserver.preserve(content)

      restored = Preserver.restore(preserved, placeholders)

      # JSON should be preserved exactly
      assert String.contains?(restored, "\"name\": \"John Doe\"")
      assert String.contains?(restored, "\"email\": \"john@example.com\"")
      assert String.contains?(restored, "curl -X POST")
    end

    test "handles math-heavy documentation" do
      content = """
      # Mathematical Formulas

      The quadratic formula is:

      $$
      x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}
      $$

      For inline math, use $x^2$ or $\\alpha + \\beta$.

      In code:

      ```python
      import math

      def quadratic(a, b, c):
          discriminant = b**2 - 4*a*c
          return (-b + math.sqrt(discriminant)) / (2*a)
      ```

      The result when $a=1$, $b=2$, $c=1$ is $x=-1$.
      """

      {preserved, placeholders} = Preserver.preserve(content)

      math_block_count =
        placeholders
        |> Map.keys()
        |> Enum.count(&String.contains?(&1, "MATH_BLOCK"))

      math_inline_count =
        placeholders
        |> Map.keys()
        |> Enum.count(&String.contains?(&1, "MATH_INLINE"))

      assert math_block_count == 1
      assert math_inline_count >= 4

      restored = Preserver.restore(preserved, placeholders)

      assert String.contains?(restored, "\\frac{-b")
      assert String.contains?(restored, "$x^2$")
      assert String.contains?(restored, "discriminant = b**2")
    end
  end
end
