defmodule TranslateMd.ChunkerTest do
  use ExUnit.Case, async: true

  alias TranslateMd.Chunker

  describe "split/2" do
    test "returns empty list for empty content" do
      assert Chunker.split("", 1000) == []
    end

    test "returns single chunk for small content" do
      content = "# Title\n\nThis is a paragraph."
      result = Chunker.split(content, 1000)

      assert length(result) == 1
      assert [{0, chunk}] = result
      assert chunk =~ "Title"
      assert chunk =~ "paragraph"
    end

    test "splits content into multiple chunks when exceeding chunk_size" do
      # 创建足够大的内容
      para1 = String.duplicate("Word ", 100)
      para2 = String.duplicate("Text ", 100)
      para3 = String.duplicate("More ", 100)
      content = "#{para1}\n\n#{para2}\n\n#{para3}"

      # 使用较小的 chunk_size
      result = Chunker.split(content, 200)

      assert length(result) > 1

      # 验证索引是连续的
      indices = Enum.map(result, fn {idx, _} -> idx end)
      assert indices == Enum.to_list(0..(length(result) - 1))
    end

    test "preserves code blocks" do
      content = """
      # Title

      ```elixir
      def hello do
        IO.puts("world")
      end
      ```

      Some text after code.
      """

      result = Chunker.split(content, 5000)
      assert [{0, chunk}] = result
      assert chunk =~ "```elixir"
      assert chunk =~ "def hello do"
      assert chunk =~ "```"
    end

    test "handles content with only paragraphs" do
      content = "Para 1\n\nPara 2\n\nPara 3"
      result = Chunker.split(content, 5000)

      assert [{0, chunk}] = result
      assert chunk =~ "Para 1"
      assert chunk =~ "Para 2"
      assert chunk =~ "Para 3"
    end
  end

  describe "split_into_paragraphs/1" do
    test "splits by double newlines" do
      content = "First\n\nSecond\n\nThird"
      result = Chunker.split_into_paragraphs(content)

      assert result == ["First", "Second", "Third"]
    end

    test "handles multiple consecutive newlines" do
      content = "First\n\n\n\nSecond"
      result = Chunker.split_into_paragraphs(content)

      assert result == ["First", "Second"]
    end

    test "removes empty paragraphs" do
      content = "\n\nFirst\n\n\n\n"
      result = Chunker.split_into_paragraphs(content)

      assert result == ["First"]
    end
  end

  describe "group_paragraphs/2" do
    test "groups small paragraphs together" do
      paragraphs = ["Short 1", "Short 2", "Short 3"]
      result = Chunker.group_paragraphs(paragraphs, 100)

      assert length(result) == 1
      assert hd(result) =~ "Short 1"
      assert hd(result) =~ "Short 2"
      assert hd(result) =~ "Short 3"
    end

    test "splits when exceeding max_size" do
      paragraphs = [
        String.duplicate("a", 50),
        String.duplicate("b", 50),
        String.duplicate("c", 50)
      ]

      result = Chunker.group_paragraphs(paragraphs, 60)

      assert length(result) == 3
    end

    test "handles single large paragraph" do
      paragraphs = [String.duplicate("x", 200)]
      result = Chunker.group_paragraphs(paragraphs, 100)

      assert length(result) == 1
      assert hd(result) == String.duplicate("x", 200)
    end
  end

  describe "stats/2" do
    test "returns correct statistics" do
      content = "Para 1\n\nPara 2\n\nPara 3"
      stats = Chunker.stats(content, 5000)

      assert stats.total_chars == String.length(content)
      assert stats.chunk_count == 1
      assert is_list(stats.chunk_sizes)
      assert stats.avg_chunk_size > 0
    end

    test "returns zero avg for empty content" do
      stats = Chunker.stats("", 1000)

      assert stats.chunk_count == 0
      assert stats.avg_chunk_size == 0
    end
  end
end
