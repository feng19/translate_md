defmodule TranslateMd.CLITest do
  use ExUnit.Case, async: true

  alias TranslateMd.CLI

  describe "parse_args/1" do
    test "returns help for -h flag" do
      assert CLI.parse_args(["-h"]) == {:help}
      assert CLI.parse_args(["--help"]) == {:help}
    end

    test "returns show_prompt for --show-default-prompt flag" do
      assert CLI.parse_args(["--show-default-prompt"]) == {:show_prompt}
    end

    test "returns error when no input file" do
      assert {:error, "请指定输入文件"} = CLI.parse_args([])
    end

    test "parses input file" do
      assert {:ok, config} = CLI.parse_args(["test.md"])
      assert config.input_file == "test.md"
      assert config.output_file == "test_zh.md"
    end

    test "parses model option" do
      assert {:ok, config} = CLI.parse_args(["-m", "gemma2", "test.md"])
      assert config.model == "gemma2"

      assert {:ok, config} = CLI.parse_args(["--model", "llama3", "test.md"])
      assert config.model == "llama3"
    end

    test "parses output option" do
      assert {:ok, config} = CLI.parse_args(["-o", "output.md", "test.md"])
      assert config.output_file == "output.md"
    end

    test "parses chunk_size option" do
      assert {:ok, config} = CLI.parse_args(["-s", "5000", "test.md"])
      assert config.chunk_size == 5000
    end

    test "parses temperature option" do
      assert {:ok, config} = CLI.parse_args(["-t", "0.5", "test.md"])
      assert config.temperature == 0.5
    end

    test "parses concurrency option" do
      assert {:ok, config} = CLI.parse_args(["-c", "8", "test.md"])
      assert config.concurrency == 8
    end

    test "parses debug option" do
      assert {:ok, config} = CLI.parse_args(["-d", "test.md"])
      assert config.debug == true

      assert {:ok, config} = CLI.parse_args(["--debug", "test.md"])
      assert config.debug == true
    end

    test "parses multiple options" do
      args = [
        "-m",
        "gemma2",
        "-c",
        "8",
        "-s",
        "5000",
        "-t",
        "0.5",
        "-d",
        "-o",
        "output.md",
        "input.md"
      ]

      assert {:ok, config} = CLI.parse_args(args)
      assert config.model == "gemma2"
      assert config.concurrency == 8
      assert config.chunk_size == 5000
      assert config.temperature == 0.5
      assert config.debug == true
      assert config.output_file == "output.md"
      assert config.input_file == "input.md"
    end

    test "returns error for invalid options" do
      assert {:error, _} = CLI.parse_args(["--invalid-option", "test.md"])
    end
  end
end
