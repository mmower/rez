defmodule Rez.DocsTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  alias Rez.Docs

  @expected_topics ~w(overview syntax values elements directives schema templates
                      navigation events behaviours runtime gotchas)

  test "embeds a non-empty reference" do
    assert String.length(Docs.reference()) > 1000
  end

  test "has all the expected topics, each with a summary" do
    topics = Docs.topics()
    assert Enum.map(topics, &elem(&1, 0)) == @expected_topics
    assert Enum.all?(topics, fn {_name, summary} -> summary != "" end)
  end

  test "returns the text of a topic" do
    assert {:ok, text} = Docs.topic("gotchas")
    assert String.starts_with?(text, "## gotchas")
    refute text =~ "## runtime"
  end

  test "topic lookup ignores case" do
    assert {:ok, _} = Docs.topic("Events")
  end

  test "run prints a topic and returns :ok" do
    output = capture_io(fn -> assert :ok = Docs.run(["events"]) end)
    assert output =~ "RezEvent.playCard"
  end

  test "run lists topics" do
    output = capture_io(fn -> assert :ok = Docs.run(["topics"]) end)
    assert output =~ "templates"
  end

  test "run returns :error for an unknown topic" do
    output = capture_io(fn -> assert :error = Docs.run(["nope"]) end)
    assert output =~ "Unknown topic 'nope'"
  end
end
