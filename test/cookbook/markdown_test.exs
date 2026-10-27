defmodule Rez.Cookbook.MarkdownTest do
  use ExUnit.Case
  alias Rez.Cookbook.Markdown

  test "renders headings and paragraphs" do
    assert Markdown.to_html("# Title\n\nSome text") == "<h1>Title</h1>\n<p>Some text</p>\n"
  end

  test "renders inline formatting without adding whitespace" do
    assert Markdown.to_html("*em* **strong** `code` ~~del~~") ==
             "<p><em>em</em> <strong>strong</strong> <code class=\"inline\">code</code> <del>del</del></p>\n"
  end

  test "renders links and images" do
    assert Markdown.to_html(~s{[link](http://a.com "t") ![alt](a.png)}) ==
             ~s{<p><a href="http://a.com" title="t">link</a> <img src="a.png" alt="alt"></p>\n}
  end

  test "renders lists" do
    assert Markdown.to_html("- one\n- two") ==
             "<ul>\n<li>one</li>\n<li>two</li>\n</ul>\n"

    assert Markdown.to_html("1. a\n2. b") ==
             "<ol>\n<li>a</li>\n<li>b</li>\n</ol>\n"
  end

  test "escapes code blocks" do
    assert Markdown.to_html("```elixir\nx = 1 < 2 && true\n```") ==
             ~s{<pre><code class="elixir">x = 1 &lt; 2 &amp;&amp; true</code></pre>\n}
  end

  test "escapes text" do
    assert Markdown.to_html("Tom & Jerry say \"hi\"") ==
             "<p>Tom &amp; Jerry say &quot;hi&quot;</p>\n"
  end

  test "passes raw HTML blocks through" do
    assert Markdown.to_html(~s{<div class="x">raw <b>html</b></div>}) ==
             ~s{<div class="x">raw <b>html</b></div>\n}
  end

  test "renders footnotes" do
    html = Markdown.to_html("Text[^1]\n\n[^1]: The note.")

    assert html =~ ~s{<a href="#fn:1" id="fnref:1" class="footnote" title="see footnote">1</a>}
    assert html =~ ~s{<li id="fn:1">}
    assert html =~ "&#x21A9;"
    assert html =~ "<p>The note.</p>"
  end

  test "renders tables" do
    html = Markdown.to_html("| a | b |\n|---|---|\n| 1 | 2 |")

    assert html =~ "<table>"
    assert html =~ ~s{<th style="text-align: left;">a</th>}
    assert html =~ ~s{<td style="text-align: left;">2</td>}
  end

  test "wraps a page" do
    html = Markdown.to_html_page("# Title")

    assert html =~ "<!DOCTYPE html>"
    assert html =~ "<h1>Title</h1>"
  end
end
