# frozen_string_literal: true

require "spec_helper"
require "rubocop/propitech/plugin"
require "tmpdir"

RSpec.describe RuboCop::Cop::Propitech::FileOutsideAllowList, :config do
  let(:cop_config) do
    {
      "Include" => ["spec/system/components/**/*_spec.rb"],
      "AllowedFiles" => ["spec/system/components/old_spec.rb", "spec/system/components/legacy/**/*"]
    }
  end

  it "flags a file outside the allow-list once, on its first line" do
    expect_offense(<<~RUBY, "spec/system/components/new_card_spec.rb")
      RSpec.describe "New card", type: :system do
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{described_class::MSG}
        it "works" do
        end
      end
    RUBY
  end

  it "passes a file the allow-list names" do
    expect_no_offenses(<<~RUBY, "spec/system/components/old_spec.rb")
      RSpec.describe "Old card", type: :system do
      end
    RUBY
  end

  it "passes a file a glob of the allow-list matches" do
    expect_no_offenses(<<~RUBY, "spec/system/components/legacy/deep/card_spec.rb")
      RSpec.describe "Legacy card", type: :system do
      end
    RUBY
  end

  it "passes a file outside the Include glob" do
    expect_no_offenses(<<~RUBY, "spec/system/users/sessions_spec.rb")
      RSpec.describe "Sessions", type: :system do
      end
    RUBY
  end

  it "is silenced by a disable comment on the first line" do
    expect_no_offenses(<<~RUBY, "spec/system/components/new_card_spec.rb")
      # rubocop:disable Propitech/FileOutsideAllowList -- tests the drag handle in a real browser
      RSpec.describe "New card", type: :system do
      end
    RUBY
  end

  it "reports an empty file in a frozen directory" do
    cop = described_class.new(RuboCop::Config.new("Propitech/FileOutsideAllowList" => cop_config))
    source = RuboCop::ProcessedSource.new("", RUBY_VERSION.to_f, "spec/system/components/empty_spec.rb")
    report = RuboCop::Cop::Commissioner.new([cop]).investigate(source)
    expect(report.offenses.size).to eq(1)
  end

  context "with the documented form, run next to the default cops" do
    let(:documented) do
      <<~SPEC
        # rubocop:disable Propitech/FileOutsideAllowList -- tests the drag handle in a real browser
        # frozen_string_literal: true

        RSpec.describe "New card", type: :system do
        end
        # rubocop:enable Propitech/FileOutsideAllowList
      SPEC
    end
    let(:config) do
      <<~YAML
        plugins: rubocop-propitech
        AllCops:
          NewCops: enable
          SuggestExtensions: false
        Propitech/FileOutsideAllowList:
          Enabled: true
          Include:
            - 'spec/system/components/**/*_spec.rb'
      YAML
    end
    let(:cops) do
      %w[Propitech/FileOutsideAllowList Lint/MissingCopEnableDirective
         Lint/RedundantCopDisableDirective Style/FrozenStringLiteralComment]
    end

    def run_cli(dir)
      output = StringIO.new
      Dir.chdir(dir) do
        $stdout = output
        RuboCop::CLI.new.run(["--format", "emacs", "spec"])
      ensure
        $stdout = STDOUT
      end
      output.string
    end

    def offences_for(source)
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p(File.join(dir, "spec/system/components"))
        File.write(File.join(dir, ".rubocop.yml"), config)
        File.write(File.join(dir, "spec/system/components/new_card_spec.rb"), source)
        run_cli(dir).lines.grep(/#{Regexp.union(cops)}/).join
      end
    end

    it "reports the file without the escape" do
      expect(offences_for(documented.lines[1..-2].join)).to include("Propitech/FileOutsideAllowList")
    end

    it "finds no offence on the documented escape" do
      expect(offences_for(documented)).to eq("")
    end
  end

  context "with no allow-list" do
    let(:cop_config) { { "Include" => ["spec/system/components/**/*_spec.rb"] } }

    it "flags every file under Include" do
      expect_offense(<<~RUBY, "spec/system/components/old_spec.rb")
        x = 1
        ^^^^^ #{described_class::MSG}
      RUBY
    end
  end

  it "ships disabled" do
    default = YAML.load_file(File.expand_path("../../../../config/default.yml", __dir__))
    expect(default.fetch("Propitech/FileOutsideAllowList")).to include("Enabled" => false)
  end
end
