# frozen_string_literal: true

module RuboCop
  module Cop
    module Propitech
      # Caps each full-line comment of a run at MaxCommentLineLength, counted from the `#`.
      # @note Mixed into CommentBudget, whose #schema_block, #directive_line? and #tag_content it calls.
      module CommentLineLength
        LINE_MSG = "Comment line is %<length>d characters long, over the %<max>d-character limit " \
                   "(MaxCommentLineLength)."

        private

        def check_line_lengths(run)
          exempt = schema_block(run)
          run.each do |comment|
            next if exempt.include?(comment) || directive_line?(comment) || single_token?(comment)

            length = comment.text.length
            next if length <= max_comment_line_length

            add_offense(excess_range(comment), message: format(LINE_MSG, length: length, max: max_comment_line_length))
          end
        end

        def excess_range(comment)
          range = comment.source_range
          range.with(begin_pos: range.begin_pos + max_comment_line_length)
        end

        def single_token?(comment)
          tag_content(comment).strip.match?(/\A\S+\z/)
        end

        def max_comment_line_length
          cop_config.fetch("MaxCommentLineLength", 100)
        end
      end
    end
  end
end
