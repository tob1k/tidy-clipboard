# frozen_string_literal: true

require "tidy_claude_clipboard"

RSpec.describe TidyClaudeClipboard do
  describe ".tidy" do
    context "marker stripping" do
      it "strips ⏺ markers" do
        expect(described_class.tidy("⏺ Hello world\n")).to eq("Hello world")
      end

      it "strips indented ⏺ markers" do
        expect(described_class.tidy("  ⏺ Hello world\n")).to eq("Hello world")
      end

      it "converts ▎ to blockquote" do
        expect(described_class.tidy("▎ Some quote\n")).to eq("> Some quote")
      end

      it "converts indented ▎ to blockquote" do
        expect(described_class.tidy("  ▎ Some quote\n")).to eq("> Some quote")
      end
    end

    context "dedenting" do
      it "strips common leading whitespace" do
        input = "  line one\n  line two\n"
        expect(described_class.tidy(input)).to eq("line one line two")
      end

      it "skips lines at column 0 when computing indent" do
        input = "⏺ first\n\n  second line\n  third line\n"
        expect(described_class.tidy(input)).to eq("first\n\nsecond line third line")
      end

      it "preserves blank lines between paragraphs" do
        input = "  para one\n\n  para two\n"
        expect(described_class.tidy(input)).to eq("para one\n\npara two")
      end
    end

    context "blockquote merging" do
      it "joins consecutive blockquote lines" do
        input = "  ▎ first part\n  ▎ second part\n"
        expect(described_class.tidy(input)).to eq("> first part second part")
      end

      it "keeps separate blockquotes apart" do
        input = "  ▎ quote one\n\n  ▎ quote two\n"
        expect(described_class.tidy(input)).to eq("> quote one\n\n> quote two")
      end
    end

    context "line rejoining" do
      it "joins hard-wrapped prose" do
        input = "  This is a long sentence that was\n  wrapped at the terminal width.\n"
        expect(described_class.tidy(input)).to eq(
          "This is a long sentence that was wrapped at the terminal width."
        )
      end

      it "joins list item continuations" do
        input = "  - A list item that wraps\n  to the next line.\n"
        expect(described_class.tidy(input)).to eq("- A list item that wraps to the next line.")
      end

      it "preserves separate list items" do
        input = "  - First item\n  - Second item\n"
        expect(described_class.tidy(input)).to eq("- First item\n\n- Second item")
      end

      it "preserves nested list items under their parent" do
        input = "  - Parent item\n    - Child one\n    - Child two\n"
        expect(described_class.tidy(input)).to eq("- Parent item\n  - Child one\n  - Child two")
      end

      it "preserves code blocks indented relative to prose" do
        input = "  Some prose.\n\n      def hello\n        puts 'hi'\n      end\n"
        expect(described_class.tidy(input)).to eq("Some prose.\n\n    def hello\n      puts 'hi'\n    end")
      end
    end

    context "list spacing" do
      it "double-spaces top-level list items" do
        input = "  - First\n  - Second\n  - Third\n"
        expect(described_class.tidy(input)).to eq("- First\n\n- Second\n\n- Third")
      end

      it "does not double-space nested items" do
        input = "  - Parent\n    - Child one\n    - Child two\n  - Next parent\n"
        expect(described_class.tidy(input)).to eq(
          "- Parent\n  - Child one\n  - Child two\n\n- Next parent"
        )
      end
    end

    context "prose between blockquotes" do
      it "preserves prose paragraphs between blockquotes" do
        input = <<~INPUT
          ▎ First quote.

          Some prose in between.

          ▎ Second quote.
        INPUT
        expected = "> First quote.\n\nSome prose in between.\n\n> Second quote."
        expect(described_class.tidy(input)).to eq(expected)
      end
    end

    context "full Claude Code output" do
      it "tidies a realistic example" do
        input = <<~INPUT
          ⏺ Here is the summary. The key finding was that
            the auth middleware was rejecting valid tokens.

            ▎ Emergency events requiring urgent response.
            ▎ Ambulance calls and hospitalisations.

            - First item with a long description that
            wraps to the next line.
              - Nested item one.
              - Nested item two.
            - Second top-level item.
        INPUT

        result = described_class.tidy(input)

        expect(result).to include("Here is the summary. The key finding")
        expect(result).to include("> Emergency events requiring urgent response. Ambulance calls and hospitalisations.")
        expect(result).to include("- First item with a long description that wraps to the next line.")
        expect(result).to include("  - Nested item one.\n  - Nested item two.")
        expect(result).to include("\n\n- Second top-level item.")
        expect(result).not_to include("⏺")
        expect(result).not_to include("▎")
      end
    end
  end
end
