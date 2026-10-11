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
(`*Form.new`, which also covers the idiomatic blank form built to render a
dynamic nested-row template). An inline callback lambda (simple_form's
`label_method`, a component's `page_url`) is also fine; only a lambda captured
in a local is flagged.

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

> **Seed cops.** `Propitech/SeedUsesFactory` and `Propitech/SeedUsesContainer`
> ship in the [`business_logic`](https://github.com/propitech/business_logic)
> gem. Enable them with `plugins: [business_logic]`. `rubocop-propitech` does
> not define them.

### `Propitech/CommentBudget`

Caps a comment run (consecutive lines starting with `#`, ignoring leading
whitespace) at a line budget that depends on what the run sits directly
above. Directly above a class or module definition the budget is
`MaxClassProseLines` (default 1); anywhere else (a constant, a method
definition, another code line, or nothing) the budget is `MaxProseLines`
(default 2). A run passes when it is one of three kinds: a directive (a
magic comment, a shebang, an `annotaterb` schema block, or a line carrying a
`rubocop:`, `reek:` or `brakeman:` marker), a YARDoc usage block, or a run
within the line budget for its position. A YARDoc usage block is an optional
summary (itself capped at the same budget as its position) followed only by
tag lines from YARD's standard set (`@param`, `@return`, `@raise`, `@yield`,
`@yieldparam`, `@yieldreturn`, `@example`, `@see`, `@deprecated`, `@api`,
`@attr`, `@attr_reader`, `@attr_writer`, `@abstract`, `@option`, `@note`,
`@overload`, `@private`, `@todo`, `@since`, `@author`, `@version`), an
indented continuation under any tag, or a bare `#` line anywhere in the
block. A continuation under a tag carries no line-count cap of its own, by design:
the tag it continues is what marks the run as a YARDoc usage block. A
trailing comment on a code line (`foo # bar`) never joins a run,
and a `=begin`/`=end` block comment is outside the cop's scope.

The cop also caps every full-line comment at `MaxCommentLineLength`
characters (default 100), counted from the `#` to the end of the line, so a
paragraph cannot pass the line budget by being squeezed onto one line. A
YARD tag's continuation line counts like any other. A directive line is
exempt, and so is a line whose text is a single token with no spaces, such
as a URL. Each over-long line is reported on its own, with the excess
characters highlighted; there is no autocorrect.

Ships disabled by default; enable it once a repository's comment sweep is
done.

```ruby
# bad
# The vendor's webhook retries with a stale signature after a timeout.
# This handler re-verifies each retry against the cached payload.
class Handler
end

# good
# Re-verifies a retried webhook against the cached payload.
# @param payload [Hash]
def handle_retry(payload); end
```

### `Propitech/EventStoreClientAccess`

Keeps the event store behind the app's `DomainEvents` wrapper, as Rule 5 of
movely's `docs/events.md` asks: code publishes through
`DomainEvents::Publisher`, and `rails_event_store` stays an implementation
detail of the wrapper. The cop flags two things outside the wrapper:

- a top-level constant named in `Namespaces` (default `RubyEventStore` and
  `RailsEventStore`), whatever is nested under it;
- the store client read or replaced through `Rails.configuration` or
  `Rails.application.config`, by an accessor named in `ClientAccessors`
  (default `event_store`).

The wrapper's own files are excluded by the shipped default: the
`app/business_logic/domain_events.rb` module, everything under
`app/business_logic/domain_events/`, `config/initializers/domain_events.rb` and
`spec/support/domain_events.rb`. Nothing else is, routes included: a mount of
the store's browser goes behind the wrapper too. `Publisher` (default
`DomainEvents::Publisher`) is the class the message points to.

```ruby
# bad
Rails.configuration.event_store.publish(event)
raise RubyEventStore::EventNotFound
mount RailsEventStore::Browser, at: "/event_store"

# good
EventPublisher.new(actor: user).publish(DomainEvents::Booking::Booked, data: {booking_id: 1})
DomainEvents.find(event_id)
```

### `Propitech/EventName`

Names each domain event as Rule 2 of movely's `docs/events.md` asks:
`<domain>.<fact>`, with the fact in the past tense. The app derives the name
from the class's place, so a `Booked` class in a `Booking` module under
`DomainEvents` is `booking.booked`. The cop checks each class declared with
`DomainEvents::Event` as its base class, or with a bare `Event` read from
inside the `DomainEvents` module, and flags its name when:

- the class does not sit exactly at `DomainEvents::<Domain>::<Fact>`, which
  the app would refuse when the event is built;
- the last word of `<Fact>` does not read as a past participle.

The past-tense test is the one movely's `domain_event` generator applies: a
word ending in `-ed` longer than three letters, or an irregular participle
from `PastParticiples` (`paid`, `sent`, `drawn` and others), optionally after
a prefix from `ParticiplePrefixes` (`overpaid`, `withdrawn`), except a word
listed in `NotPastTense` (`need`, `feed`, `seed` and others). A name the
generator accepts is never an offence. Only `class` declarations are checked;
an event class built with `Class.new` in a spec is not.

```ruby
# bad
module DomainEvents
  class Booked < Event; end        # no domain module
  module Booking
    class Book < Event; end        # not in the past tense
  end
end

# good
module DomainEvents
  module Booking
    class Booked < Event; end
  end
end
```

## Installation

Add the gem to the lint group of your `Gemfile`:

```ruby
group :development, :test do
  gem "rubocop-propitech", github: "propitech/rubocop-propitech", require: false
end
```

Requiring the gem never pulls RuboCop itself into the load path: the `Plugin`
constant autoloads, and RuboCop's own plugin loader only references it once a
consuming repo lists `rubocop-propitech` under `plugins:`.

## Usage

Enable the plugin once, in `.rubocop.yml`:

```yaml
# .rubocop.yml
plugins:
  - rubocop-propitech
```

`Propitech/NoViewAssembly` lints the Ruby in ERB. Plain `rubocop` never
enumerates `.erb` files, so the cop runs through
[erb_lint](https://github.com/Shopify/erb_lint)'s `Rubocop` linter. Point
erb_lint's own config at the RuboCop config above, and let the cop's shipped
default scope it to `app/views`:

```yaml
# .erb-lint.yml
linters:
  Rubocop:
    enabled: true
    rubocop_config:
      inherit_from:
        - .rubocop.yml
```

Because `Propitech/NoViewAssembly` is scoped to `app/views/**`, it stays inert
under a plain `rubocop` run over the rest of the tree.

`Propitech/CommentBudget` ships disabled and runs under plain `rubocop` once a
repository turns it on in the same `.rubocop.yml`:

```yaml
Propitech/CommentBudget:
  Enabled: true
```

`MaxProseLines`, `MaxClassProseLines` and `MaxCommentLineLength` are optional
overrides of its three defaults.

`Propitech/EventStoreClientAccess` ships enabled and runs under plain
`rubocop`. A repository whose wrapper lives elsewhere overrides its `Exclude`
list, and `Namespaces`, `ClientAccessors` and `Publisher` in the same way.

`Propitech/EventName` ships enabled and runs under plain `rubocop`. `Namespace`
and `BaseClass` name where the app's events live, and `PastParticiples`,
`ParticiplePrefixes` and `NotPastTense` follow the app's generator if it
changes its word lists.

## Development

```bash
bundle install
bundle exec rake   # rubocop + rspec
```

## License

Released under the [MIT License](LICENSE.txt).
