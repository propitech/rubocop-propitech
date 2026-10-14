# frozen_string_literal: true

module RuboCop
  module Cop
    module Propitech
      # Keeps a slow sign-in helper to the files that really test signing in.
      # @example Methods: [sign_in_through_form], AllowedPaths: [spec/system/users/sessions_spec.rb]
      #   # bad, in spec/system/schools/members_invite_teacher_spec.rb
      #   before { sign_in_through_form(admin) }
      #
      #   # good, in spec/system/users/sessions_spec.rb
      #   before { sign_in_through_form(user) }
      class FormSignInOutsideAllowList < Base
        MSG = "Do not call `%<method>s` outside the files that test signing in: sign in with the fast " \
              "helper, and keep the form sign-in to the allowed paths."

        DEFAULTS = {
          "Methods" => [],
          "AllowedPaths" => []
        }.freeze

        def on_send(node)
          return unless option("Methods").include?(node.method_name.to_s)
          return if allowed_path?

          add_offense(node.loc.selector, message: format(MSG, method: node.method_name))
        end
        alias on_csend on_send

        private

        def allowed_path?
          file = processed_source.file_path
          option("AllowedPaths").any? && file && file_name_matches_any?(file, "AllowedPaths", false)
        end

        def option(key)
          cop_config.fetch(key, DEFAULTS.fetch(key))
        end
      end
    end
  end
end
