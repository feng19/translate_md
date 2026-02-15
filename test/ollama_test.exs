defmodule TranslateMd.OllamaTest do
  use ExUnit.Case, async: true
  alias TranslateMd.Ollama

  describe "strip_code_block_wrapper/1" do
    test "removes markdown code block wrapper from beginning and end" do
      input = """
      ```
      ---
      title: Test
      ---

      # Hello World
      ```
      """

      expected = """
      ---
      title: Test
      ---

      # Hello World
      """

      assert Ollama.strip_code_block_wrapper(input) == String.trim(expected)
    end

    test "removes code block wrapper with language identifier" do
      input = """
      ```markdown
      # Title

      Some content here.
      ```
      """

      expected = """
      # Title

      Some content here.
      """

      assert Ollama.strip_code_block_wrapper(input) == String.trim(expected)
    end

    test "does not modify content without code block wrapper" do
      input = """
      # Title

      Some content here.

      ```python
      print("hello")
      ```

      More content.
      """

      # Content should remain unchanged (just trimmed)
      assert Ollama.strip_code_block_wrapper(input) == String.trim(input)
    end

    test "handles content with only opening code block at start" do
      # This is the actual error case from SKILL_zh.md
      input = """
      ```
      ---
      name: test
      ---

      ## Section

      | Column1 | Column2 |
      |---------|---------|
      | A | B |
      ```

      ## Another Section

      More content.
      """

      # Should remove the wrapping code block but preserve internal structure
      result = Ollama.strip_code_block_wrapper(input)
      refute String.starts_with?(result, "```")
      assert String.contains?(result, "---")
      assert String.contains?(result, "## Section")
    end

    test "handles empty content" do
      assert Ollama.strip_code_block_wrapper("") == ""
    end

    test "handles content that is only whitespace" do
      assert Ollama.strip_code_block_wrapper("   \n\n   ") == ""
    end

    test "handles code block wrapper with extra whitespace" do
      input = "  ```  \n# Title\n  ```  "
      expected = "# Title"
      assert Ollama.strip_code_block_wrapper(input) == expected
    end

    test "preserves internal code blocks while removing outer wrapper" do
      input = """
      ```
      # Documentation

      Here's some code:

      ```python
      def hello():
          print("world")
      ```

      End of docs.
      ```
      """

      result = Ollama.strip_code_block_wrapper(input)
      refute String.starts_with?(result, "```\n# Documentation")
      assert String.contains?(result, "```python")
      assert String.contains?(result, "def hello():")
    end

    test "handles mismatched code block - only opening at start" do
      input = """
      ```
      # Title

      Content without closing fence.
      """

      # Should remove the opening fence if it appears to be a wrapper
      result = Ollama.strip_code_block_wrapper(input)
      refute String.starts_with?(String.trim(result), "```")
    end

    test "handles code block in the middle - should not strip" do
      input = """
      # Title

      ```python
      print("hello")
      ```

      More content.
      """

      # Should not modify - code block is not wrapping the entire content
      assert Ollama.strip_code_block_wrapper(input) == String.trim(input)
    end
  end
end
