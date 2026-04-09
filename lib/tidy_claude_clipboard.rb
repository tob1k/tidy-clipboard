# frozen_string_literal: true

module TidyClaudeClipboard
  VERSION = "0.1.0"

  LIST_ITEM = /\A\s*(?:[-*]|\d+\.)\s/
  BLOCKQUOTE = /\A> /
  CODE_INDENT = /\A(?:    |\t)/

  def self.tidy(text)
    text.then { clean(_1) }
        .then { dedent(_1) }
        .then { rejoin(_1) }
  end

  class << self
    private

    def clean(text)
      text.gsub(/^⏺ ?/, "")
          .gsub(/^(\s*)▎ ?/, '\1> ')
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

    def rejoin(text)
      elements = []
      last_top_level = nil

      text.each_line(chomp: true) do |line|
        if line.strip.empty?
          elements << :break unless elements.last == :break
        elsif line.match?(BLOCKQUOTE) && elements.last.is_a?(String) && elements.last.match?(BLOCKQUOTE)
          elements[-1] += " #{line.sub(BLOCKQUOTE, '').strip}"
        elsif continuation?(line, elements)
          elements[-1] += " #{line.strip}"
        else
          if top_level_list_item?(line) && last_top_level
            elements << :break unless elements.last == :break
          end
          elements << line
        end

        last_top_level = elements.last if top_level_list_item?(elements.last)
      end

      elements.map { _1 == :break ? "" : _1 }.join("\n")
    end

    def continuation?(line, elements)
      return false if elements.empty? || elements.last == :break
      return false if line.match?(LIST_ITEM)
      return false if line.match?(BLOCKQUOTE)
      return false if line.match?(CODE_INDENT)
      true
    end

    def top_level_list_item?(el)
      el.is_a?(String) && el.match?(LIST_ITEM) && !el.match?(/\A\s/)
    end
  end
end
