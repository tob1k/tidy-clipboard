# frozen_string_literal: true

# Tidies text copied from Claude Code terminal sessions.
#
# Claude Code output typically has:
#   - ⏺ markers at the start of paragraphs
#   - ▎ markers for blockquotes
#   - 2-space indentation on body text
#   - Hard line breaks from terminal wrapping
#
# The pipeline: clean → dedent → merge_blockquotes → rejoin → space_list_items
module TidyClaudeClipboard
  VERSION = "0.1.0"

  LIST_ITEM = /\A\s*(?:[-*]|\d+\.)\s/   # "- foo", "  * bar", "1. baz"
  BLOCKQUOTE = /\A> /                     # "> quoted text"
  CODE_INDENT = /\A(?:    |\t)/           # 4+ spaces or tab = code

  def self.tidy(text)
    text.then { clean(_1) }
        .then { dedent(_1) }
        .then { merge_blockquotes(_1) }
        .then { rejoin(_1) }
        .then { space_list_items(_1) }
  end

  class << self
    private

    # Strip Claude-specific markers: ⏺ (paragraph) and ▎ (blockquote → >)
    def clean(text)
      text.gsub(/^⏺ ?/, "")
          .gsub(/^[ \t]*▎ ?/, "> ")
    end

    # Strip the common leading whitespace from indented lines.
    # Lines already at column 0 (like the ⏺ line) are excluded from
    # the indent calculation so they don't zero it out.
    def dedent(text)
      lines = text.lines
      indent = lines
        .reject { |l| l.strip.empty? }
        .filter_map { |l| l[/\A */].length.then { _1 if _1.positive? } }
        .min || 0
      return text if indent.zero?
      lines.map { |l| l.strip.empty? ? "\n" : l.sub(/^ {0,#{indent}}/, "") }.join
    end

    # Join consecutive "> " lines into a single blockquote.
    # Uses chunk_while to group runs of blockquote lines together.
    #   "> first line\n> second line" → "> first line second line"
    def merge_blockquotes(text)
      text.each_line(chomp: true)
          .chunk_while { |a, b| a.match?(BLOCKQUOTE) && b.match?(BLOCKQUOTE) }
          .map { |lines| merge_quote_group(lines) }
          .join("\n")
    end

    def merge_quote_group(lines)
      return lines.join("\n") unless lines.first.match?(BLOCKQUOTE)
      "> #{lines.map { _1.sub(BLOCKQUOTE, '').strip }.join(' ')}"
    end

    # Rejoin hard-wrapped continuation lines to their parent element.
    # Uses slice_before to cut at each new structural element (blank line,
    # list item, blockquote, code), then joins each group into one line.
    def rejoin(text)
      text.each_line(chomp: true)
          .slice_before { |line| new_element?(line) }
          .map { |group| join_group(group) }
          .join("\n")
    end

    # A line starts a new element if it's blank, a list item,
    # a blockquote, or indented code. Everything else is a continuation.
    def new_element?(line)
      line.strip.empty? || line.match?(LIST_ITEM) || line.match?(BLOCKQUOTE) || line.match?(CODE_INDENT)
    end

    # Collapse a group of lines into a single element.
    # Code blocks preserve their line structure; everything else joins with spaces.
    def join_group(group)
      return "" if group.first.strip.empty?
      return group.join("\n") if group.first.match?(CODE_INDENT)
      ([group.first] + group.drop(1).map(&:strip)).join(" ")
    end

    # Insert blank lines between top-level list items (not nested ones).
    # Matches a non-empty line followed by a line starting with a list marker
    # at column 0, and inserts an extra newline between them.
    def space_list_items(text)
      text.gsub(/([^\n])\n((?:[-*]|\d+\.)\s)/, "\\1\n\n\\2")
    end
  end
end
