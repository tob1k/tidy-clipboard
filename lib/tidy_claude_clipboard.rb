# frozen_string_literal: true

module TidyClaudeClipboard
  VERSION = "0.1.0"

  LIST_ITEM = /\A\s*(?:[-*]|\d+\.)\s/
  BLOCKQUOTE = /\A> /
  CODE_INDENT = /\A(?:    |\t)/

  def self.tidy(text)
    text.then { clean(_1) }
        .then { dedent(_1) }
        .then { merge_blockquotes(_1) }
        .then { rejoin(_1) }
        .then { space_list_items(_1) }
  end

  class << self
    private

    def clean(text)
      text.gsub(/^⏺ ?/, "")
          .gsub(/^[ \t]*▎ ?/, "> ")
    end

    def dedent(text)
      lines = text.lines
      indent = lines
        .reject { |l| l.strip.empty? }
        .filter_map { |l| l[/\A */].length.then { _1 if _1.positive? } }
        .min || 0
      return text if indent.zero?
      lines.map { |l| l.strip.empty? ? "\n" : l.sub(/^ {0,#{indent}}/, "") }.join
    end

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

    def rejoin(text)
      text.each_line(chomp: true)
          .slice_before { |line| new_element?(line) }
          .map { |group| join_group(group) }
          .join("\n")
    end

    def new_element?(line)
      line.strip.empty? || line.match?(LIST_ITEM) || line.match?(BLOCKQUOTE) || line.match?(CODE_INDENT)
    end

    def join_group(group)
      return "" if group.first.strip.empty?
      return group.join("\n") if group.first.match?(CODE_INDENT)
      ([group.first] + group.drop(1).map(&:strip)).join(" ")
    end

    def space_list_items(text)
      text.gsub(/([^\n])\n((?:[-*]|\d+\.)\s)/, "\\1\n\n\\2")
    end
  end
end
