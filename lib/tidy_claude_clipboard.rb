# frozen_string_literal: true

module TidyClaudeClipboard
  VERSION = "0.1.0"

  LIST_ITEM = /\A\s*(?:[-*]|\d+\.)\s/
  BLOCKQUOTE = /\A\s*> /
  CODE_INDENT = /\A(?:    |\t)/

  def self.tidy(text)
    text.then { clean(_1) }
        .then { dedent(_1) }
        .then { rejoin(_1) }
  end

  private

  def self.clean(text)
    text.gsub(/^⏺ ?/, "")
        .gsub(/^(\s*)▎ ?/, '\1> ')
  end

  def self.dedent(text)
    lines = text.lines
    indent = lines
      .reject { |l| l.strip.empty? }
      .filter_map { |l| l[/\A */].length.then { _1 if _1.positive? } }
      .min || 0

    return text if indent.zero?

    lines.map { |l| l.strip.empty? ? "\n" : l.sub(/^ {0,#{indent}}/, "") }.join
  end

  def self.rejoin(text)
    elements = []

    text.each_line(chomp: true) do |line|
      if line.strip.empty?
        elements << :break unless elements.last == :break
      elsif line.match?(BLOCKQUOTE) && elements.last&.match?(BLOCKQUOTE)
        elements[-1] += " #{line.sub(BLOCKQUOTE, '').strip}"
      elsif continuation?(line, elements)
        elements[-1] += " #{line.strip}"
      else
        elements << line
      end
    end

    # Double-space between top-level list items
    elements.flat_map.with_index do |el, i|
      prev_top = elements[0...i].reverse.find { |e| e == :break || top_level_list_item?(e) }
      if top_level_list_item?(el) && top_level_list_item?(prev_top)
        [:break, el]
      else
        [el]
      end
    end
    .map { _1 == :break ? "" : _1 }
    .join("\n")
  end

  def self.continuation?(line, elements)
    return false if elements.empty? || elements.last == :break
    return false if line.match?(LIST_ITEM)
    return false if line.match?(BLOCKQUOTE)
    return false if line.match?(CODE_INDENT)
    true
  end

  def self.top_level_list_item?(el)
    el.is_a?(String) && el.match?(LIST_ITEM) && !el.match?(/\A\s/)
  end
end
