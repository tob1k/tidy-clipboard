# frozen_string_literal: true

module TidyClaudeClipboard
  VERSION = "0.1.0"

  def self.tidy(text)
    cleaned = strip_claude_markers(text)
    dedented = dedent(cleaned)
    process_blocks(dedented)
  end

  private

  def self.strip_claude_markers(text)
    text.gsub(/^⏺ ?/, "")
      .gsub(/^(\s*)▎ ?/, '\1> ')
  end

  def self.dedent(text)
    lines = text.lines
    indents = lines
      .reject { |l| l.strip.empty? }
      .map { |l| l[/\A */].length }
      .select(&:positive?)

    indent = indents.min || 0
    return text if indent.zero?

    lines.map { |l| l.strip.empty? ? "\n" : l.sub(/^ {0,#{indent}}/, "") }.join
  end

  def self.process_blocks(text)
    blocks = text.split(/\n{2,}/)
    blocks.map { |block| tidy_block(block) }.join("\n\n")
  end

  def self.tidy_block(block)
    lines = block.lines.map(&:chomp)
    lines.reject! { |l| l.strip.empty? }
    return "" if lines.empty?

    return block.chomp if code_block?(lines)
    return rejoin_list(lines) if list_block?(lines)
    return rejoin_blockquote(lines) if blockquote_block?(lines)

    lines.join(" ").squeeze(" ")
  end

  def self.rejoin_list(lines)
    items = []
    lines.each do |line|
      if line.match?(/\A\s*(?:[-*]|\d+\.)\s/) || items.empty?
        items << line
      else
        items[-1] = "#{items[-1]} #{line.strip}"
      end
    end

    # Double-space between top-level items, single-space nested
    result = [items.first]
    items.drop(1).each do |item|
      nested = item.match?(/\A\s+/)
      result << (nested ? item : "\n#{item}")
    end
    result.join("\n")
  end

  def self.rejoin_blockquote(lines)
    # Join consecutive > lines into single blockquotes
    result = []
    lines.each do |line|
      content = line.sub(/\A\s*> /, "")
      if result.empty?
        result << "> #{content}"
      else
        result[-1] = "#{result[-1]} #{content}"
      end
    end
    result.join("\n")
  end

  def self.blockquote_block?(lines)
    lines.first&.match?(/\A\s*> /)
  end

  def self.code_block?(lines)
    lines.any? { |l| l.start_with?("    ", "\t") && !l.strip.empty? }
  end

  def self.list_block?(lines)
    lines.first&.match?(/\A\s*(?:[-*]|\d+\.)\s/)
  end
end
