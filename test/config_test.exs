defmodule TranslateMd.ConfigTest do
  use ExUnit.Case, async: true

  alias TranslateMd.Config

  describe "new/1" do
    test "creates config with default values" do
      config = Config.new()

      assert config.model == "hy-mt2-1.8b"
      assert config.chunk_size == 1200
      assert config.temperature == 0.3
      assert config.concurrency == 16
      assert config.debug == false
      assert config.url == "http://127.0.0.1:1234"
      assert config.api == :openai
    end

    test "creates config with custom values" do
      config =
        Config.new(
          model: "gemma2",
          chunk_size: 5000,
          concurrency: 8,
          debug: true
        )

      assert config.model == "gemma2"
      assert config.chunk_size == 5000
      assert config.concurrency == 8
      assert config.debug == true
    end

    test "includes input and output files" do
      config =
        Config.new(
          input_file: "test.md",
          output_file: "test_zh.md"
        )

      assert config.input_file == "test.md"
      assert config.output_file == "test_zh.md"
    end
  end

  describe "default_output_file/1" do
    test "generates _zh.md suffix for .md files" do
      assert Config.default_output_file("README.md") == "README_zh.md"
      assert Config.default_output_file("docs/guide.md") == "docs/guide_zh.md"
    end

    test "handles files without .md extension" do
      assert Config.default_output_file("file.txt") == "file_zh.txt"
      assert Config.default_output_file("doc.markdown") == "doc_zh.markdown"
    end

    test "handles files in subdirectories" do
      assert Config.default_output_file("path/to/file.md") == "path/to/file_zh.md"
    end
  end

  describe "default_system_prompt/0" do
    test "returns non-empty string" do
      prompt = Config.default_system_prompt()

      assert is_binary(prompt)
      assert String.length(prompt) > 0
      assert prompt =~ "translator"
    end
  end
end
