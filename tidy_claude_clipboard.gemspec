# frozen_string_literal: true

require_relative "lib/tidy_claude_clipboard"

Gem::Specification.new do |spec|
  spec.name = "tidy_claude_clipboard"
  spec.version = TidyClaudeClipboard::VERSION
  spec.authors = ["Toby"]
  spec.summary = "Tidy up text copied from Claude sessions"
  spec.description = "Fixes excess whitespace and hard line breaks in text copied from Claude AI conversations"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.files = Dir["lib/**/*.rb", "exe/*"]
  spec.bindir = "exe"
  spec.executables = ["tidy-clipboard"]

  spec.require_paths = ["lib"]
end
