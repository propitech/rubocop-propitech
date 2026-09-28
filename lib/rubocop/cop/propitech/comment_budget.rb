# frozen_string_literal: true

require_relative "comment_line_length"

module RuboCop
  module Cop
    module Propitech
      # Caps a comment run at a line budget set by what it sits above.
      # @example MaxProseLines: 2, MaxClassProseLines: 1, MaxCommentLineLength: 100 (defaults)
      #   # bad
      #   # The vendor's webhook retries with a stale signature after a
      #   # timeout, so this handler re-verifies each retry.
      #   class Handler
      #   end
      #
      #   # good
      #   # Re-verifies a retried webhook against the cached payload.
      #   # @param payload [Hash]
      #   def handle_retry(payload); end
      class CommentBudget < Base
        include CommentLineLength

        MSG = "Comments are a YARDoc usage block, a directive, or an external constraint note " \
              "within the line budget; rationale goes to the pull request, Linear or Notion " \
              "(AGENTS.md#code-style)."

        SCHEMA_HEADER = /\A#\s*==\s*Schema Information\b/
        SCHEMA_SECTION = /\A\#\s*(?:Table\ name:|Database\ name:|Schema\ version:|Indexes\b|
                                   Foreign\ Keys\b|Check\ Constraints\b|Unique\ Constraints\b|
                                   Exclusion\ Constraints\b|Enums\b)/x
        SCHEMA_DETAIL = /\A#\s{2,}\S/
        MARKER = /\A#\s*:?(?:rubocop|reek|brakeman):/
        TAG = /\A@(?:yieldparam|yieldreturn|yield|param|return|raise|example|see|deprecated|api|
                    attr_reader|attr_writer|attr|abstract|option|note|overload|private|todo|
                    since|author|version)\b/x
        CLASS_OR_MODULE = /\A\s*(?:class|module)\b/

        def on_new_investigation
          comment_runs.each do |run|
            check_run(run)
            check_line_lengths(run)
          end
        end

        private

        def comment_runs
          standalone_comments.slice_when { |prev, curr| curr.loc.line != prev.loc.line + 1 }
        end

        def standalone_comments
          processed_source.comments.select do |comment|
            comment_line?(processed_source[comment.loc.line - 1])
          end
        end

        def check_run(run)
          return if directive_run?(run) || yardoc_run?(run) || run.size <= max_lines_for(run)

          add_offense(run.first, message: MSG)
        end

        def schema_block(run)
          header_index = run.index { |comment| comment.text.match?(SCHEMA_HEADER) }
          return [] unless header_index

          run[header_index..].take_while { |comment| schema_line?(comment) }
        end

        def max_lines_for(run)
          above_class_or_module?(run) ? max_class_prose_lines : max_prose_lines
        end

        def above_class_or_module?(run)
          next_line = processed_source[run.last.loc.line]
          next_line&.match?(CLASS_OR_MODULE) || false
        end

        def max_class_prose_lines
          cop_config.fetch("MaxClassProseLines", 1)
        end

        def max_prose_lines
          cop_config.fetch("MaxProseLines", 2)
        end

        def directive_run?(run)
          block = schema_block(run)
          return run.all? { |comment| directive_line?(comment) } if block.empty?
          return false unless block.last.equal?(run.last)

          run.take_while { |comment| !block.first.equal?(comment) }.all? { |comment| directive_line?(comment) }
        end

        def directive_line?(comment)
          shebang?(comment) || RuboCop::MagicComment.parse(comment.text).valid? || comment.text.match?(MARKER)
        end

        def shebang?(comment)
          comment.loc.line == 1 && comment.text.start_with?("#!")
        end

        def schema_line?(comment)
          text = comment.text
          text.match?(SCHEMA_HEADER) || text.match?(SCHEMA_SECTION) || text.match?(SCHEMA_DETAIL) ||
            text.match?(/\A#\s*\z/)
        end

        def yardoc_run?(run)
          contents = run.map { |comment| tag_content(comment) }
          summary = contents.take_while { |content| !tag_line?(content) && !blank_line?(content) }
          return false if summary.size > max_lines_for(run)

          tagged_lines?(contents[summary.size..])
        end

        def tag_content(comment)
          comment.text.sub(/\A#\s?/, "")
        end

        def tagged_lines?(contents)
          current_tag = false

          contents.all? do |content|
            current_tag = true if tag_line?(content)
            tag_line?(content) || blank_line?(content) || (current_tag && continuation?(content))
          end
        end

        def tag_line?(content)
          content.match?(TAG)
        end

        def blank_line?(content)
          content.strip.empty?
        end

        def continuation?(content)
          content.match?(/\A\s+\S/)
        end
      end
    end
  end
end
