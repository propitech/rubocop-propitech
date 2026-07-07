# rubocop-propitech

Cross-cutting [RuboCop](https://rubocop.org) cops for Propitech Rails apps,
packaged as a [lint_roller](https://github.com/standardrb/lint_roller) plugin.
Domain-specific cops live with their gem (spec-writing cops ship in
`business_logic`); this gem is the home for rules that apply across any
Propitech Rails codebase.

## Cops

### `Propitech/NoViewAssembly`

Keeps data and object assembly out of view templates. A view consumes values an
earlier layer already produced (controller-assigned instance variables, helpers,
ViewComponents, route and i18n helpers, Design tokens); it must not instantiate a
domain, query, or presenter object, run an ActiveRecord query, or capture a
lambda in a local.

Allowed, because they are view-rendering machinery rather than data assembly: a
ViewComponent render target (`*::Component.new`) and a simple_form backing object
(`*Form.new`). An inline callback lambda (simple_form's `label_method`, a
component's `page_url`) is also fine; only a lambda captured in a local is
flagged.

```erb
<%# bad %>
<% label = SpaceLabel.new(space).to_s %>
<% rows  = Taxon.kind_amenity.order(:name).to_a %>
<% step  = ->(on:) { some_path(on:) } %>

<%# good %>
<%= space_label(space) %>
<%= render Card::Component.new(row: row) %>
<%= link_to t(".prev"), some_path(on: @cursor) %>
```

### `Propitech/SeedUsesFactory`

Enforces that seed data is built with FactoryBot factories and their traits. A
factory is the only sanctioned way to build a seed row: the trait is the shared
vocabulary between seeds and specs, so seed rows and test rows exercise the same
code and never drift.

Two constructs are flagged inside a seed file: a hand-rolled model create (a
constant receiver `.create` / `.create!` — `FactoryBot.create` /
`FactoryGirl.create` are allowed, and `find_or_create_by` / `create_with` pass
untouched), and a `Commands::…` business-logic command invocation (a command
runs operation side-effects a seed must not depend on).

```ruby
# bad
Space.create!(name: "Studio A")
Commands::Spaces::Create.call(name: "Studio A")

# good
FactoryBot.create(:space, :studio, name: "Studio A")
```

Scoped to `db/seeds.rb` and `db/seeds/**/*.rb`, so it stays inert over the rest
of the tree. Unlike `NoViewAssembly`, this cop lints plain Ruby, so a plain
`rubocop` run enforces it.

## Installation

Add the gem to the lint group of your `Gemfile`:

```ruby
group :development, :test do
  gem "rubocop-propitech", github: "propitech/rubocop-propitech", require: false
end
```

## Usage

The cop lints the Ruby in ERB, so it runs through
[erb_lint](https://github.com/Shopify/erb_lint)'s `Rubocop` linter rather than
plain `rubocop` (which never enumerates `.erb`). Enable the plugin in the RuboCop
config that erb_lint inherits, and let its shipped default scope it to
`app/views`:

```yaml
# .rubocop.yml
plugins:
  - rubocop-propitech
```

```yaml
# .erb-lint.yml
linters:
  Rubocop:
    enabled: true
    rubocop_config:
      inherit_from:
        - .rubocop.yml
```

Because the cop is scoped to `app/views/**`, it stays inert under a plain
`rubocop` run over the rest of the tree.

## Development

```bash
bundle install
bundle exec rake   # rubocop + rspec
```

## License

Released under the [MIT License](LICENSE.txt).
