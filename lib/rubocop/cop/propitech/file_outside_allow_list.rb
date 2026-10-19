# frozen_string_literal: true

module RuboCop
  module Cop
    module Propitech
      # Freezes a directory: a file under `Include` that `AllowedFiles` does not list is reported once,
      # on its first line. To keep such a file, add it to `AllowedFiles` with the reason in the config,
      # or give the file a disable comment for this cop, with the reason, on line 1, the
      # `frozen_string_literal` comment on line 2, and an enable comment for this cop as the last line.
      # The disable comment has to sit on line 1, because that is where the offence is reported; the
      # enable comment keeps `Lint/MissingCopEnableDirective` quiet.
      # @example Include: [spec/system/components/**/*_spec.rb], AllowedFiles: [spec/system/components/old_spec.rb]
      #   # bad, in spec/system/components/new_card_spec.rb
      #   # frozen_string_literal: true
      #
      #   RSpec.describe "New card", type: :system do
      #   end
      #
      #   # good, in spec/system/components/new_card_spec.rb
      #   # rubocop:disable Propitech/FileOutsideAllowList -- tests the drag handle in a real browser
      #   # frozen_string_literal: true
      #
      #   RSpec.describe "New card", type: :system do
      #   end
      #   # rubocop:enable Propitech/FileOutsideAllowList
      class FileOutsideAllowList < Base
        MSG = "This file is in a frozen directory and is not on the allow-list. Add it to `AllowedFiles` " \
              "with a reason, or put `# rubocop:disable Propitech/FileOutsideAllowList -- <the browser " \
              "behaviour the file tests>` on line 1, the `frozen_string_literal` comment on line 2, and " \
              "`# rubocop:enable Propitech/FileOutsideAllowList` as the last line."

        DEFAULTS = {
          "AllowedFiles" => []
        }.freeze

        def on_new_investigation
          file = processed_source.file_path
          return unless file
          return if option("AllowedFiles").any? && file_name_matches_any?(file, "AllowedFiles", false)

          add_offense(first_line_range)
        end

        private

        def first_line_range
          first_line = processed_source.lines.first.to_s
          Parser::Source::Range.new(processed_source.buffer, 0, first_line.length)
        end

        def option(key)
          cop_config.fetch(key, DEFAULTS.fetch(key))
        end
      end
    end
  end
end
