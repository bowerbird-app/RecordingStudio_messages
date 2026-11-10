# frozen_string_literal: true

require "test_helper"

class AutoLinkTest < Minitest::Test
  def test_escapes_html_then_links_http_and_https
    html = RecordingStudioMessages.auto_link(
      "<script>alert(1)</script> see https://ok.example/path and http://plain.example"
    )

    assert_includes html, "&lt;script&gt;alert(1)&lt;/script&gt;"
    refute_includes html, "<script>"
    assert_includes html, '<a href="https://ok.example/path" rel="noopener noreferrer nofollow" target="_blank">https://ok.example/path</a>'
    assert_includes html, '<a href="http://plain.example" rel="noopener noreferrer nofollow" target="_blank">http://plain.example</a>'
  end

  def test_does_not_link_javascript_or_data_urls
    html = RecordingStudioMessages.auto_link("go javascript:alert(1) and data:text/html,hi")

    refute_includes html, "<a "
    assert_includes html, "javascript:alert(1)"
    assert_includes html, "data:text/html,hi"
  end

  def test_strips_trailing_punctuation_from_the_href
    html = RecordingStudioMessages.auto_link("See https://ok.example.")

    assert_includes html, 'href="https://ok.example"'
    assert_match(%r{</a>\.}, html)
  end

  def test_plain_text_without_urls_stays_escaped_text
    html = RecordingStudioMessages.auto_link("Hello & goodbye")

    assert_equal "Hello &amp; goodbye", html
  end
end
