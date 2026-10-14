# Changelog

## [Unreleased]

## [0.9.0]

- Add three spec cops, each shipping disabled and driven by configuration.
  `Propitech/FormSignInOutsideAllowList` flags a call to a method named in
  `Methods` in a file outside the `AllowedPaths` globs.
  `Propitech/AuditTagOnExampleGroup` flags a symbol named in `Tags` on
  `describe`, `context`, `feature` or `RSpec.describe` rather than on an
  example. `Propitech/StyleReadInSystemSpec` warns about a
  `getComputedStyle` or `getBoundingClientRect` string passed to
  `evaluate_script`, `evaluate_async_script` or `execute_script`, and about
  `native.size` and `native.location`, under `Include`; a
  `rubocop:disable` comment with the reason silences a read that states an
  accessibility requirement. No autocorrect.

## [0.8.0]

- Add `Propitech/SubscriberShape`: keep each event subscriber in the domain
  that reacts (Rules 3 and 4 of movely's `docs/events.md`). A class inheriting
  `DomainEvents::Subscriber` is an offence unless it is named
  `<Domain>::<Reaction>Subscriber` in `app/jobs/<domain>/<reaction>_subscriber.rb`,
  and so is a class named `...Subscriber` under `app/jobs/` that does not
  inherit it. Inside a subscriber, publishing an event is an offence (chain
  depth is one), and so is a reference to `Commands::<Other>::...` when
  `<Other>` is not the subscriber's top-level module. `BaseClass`,
  `Directory`, `NameSuffix`, `CommandsNamespace`, `EventNamespace`,
  `Publisher` and `PublishMethods` are options. Ships enabled; no
  autocorrect.

## [0.7.0]

- Add `Propitech/EventName`: name each domain event `<domain>.<fact>` with the
  fact in the past tense (Rule 2 of movely's `docs/events.md`). A class whose
  base class is `DomainEvents::Event` (or a bare `Event` read from inside the
  `DomainEvents` module) is an offence unless it sits at
  `DomainEvents::<Domain>::<Fact>` and the last word of `<Fact>` reads as a
  past participle. The past-tense test is the one movely's `domain_event`
  generator applies, so a name the generator accepts is never an offence.
  `Namespace`, `BaseClass`, `PastParticiples`, `ParticiplePrefixes` and
  `NotPastTense` are options. Ships enabled; no autocorrect.

## [0.6.0]

- Add `Propitech/EventStoreClientAccess`: keep the event store behind the
  app's `DomainEvents` wrapper (Rule 5 of movely's `docs/events.md`). Flags a
  top-level `RubyEventStore` or `RailsEventStore` constant, and the store
  client read or replaced through `Rails.configuration.event_store` or
  `Rails.application.config.event_store`, outside the wrapper's module, its
  directory, its initializer and its spec support. Routes are not excluded.
  `Namespaces`, `ClientAccessors` and `Publisher` are options. Ships enabled;
  no autocorrect.

## [0.5.0]

- `Propitech/CommentBudget` caps each full-line comment at
  `MaxCommentLineLength` characters (default 100), counted from the `#` with
  leading indentation excluded. A run budget counts lines, so a paragraph
  squeezed onto one long line used to pass it; each over-long line is now
  reported at its own position, separately from the run budget. A directive
  line (a magic comment, a shebang, an `annotaterb` schema line, a `rubocop:`,
  `reek:` or `brakeman:` marker) and a line holding a single token such as a
  URL are exempt. No autocorrect.

## [0.4.0]

- Add `Propitech/CommentBudget`: cap a comment run at `MaxClassProseLines`
  (default 1) directly above a class or module, `MaxProseLines` (default 2)
  elsewhere. A directive, a YARDoc usage block, or a run within the budget
  for its position passes; ships disabled by default so a repository can
  sweep its comments before enabling it.
- Raise `required_ruby_version` to `>= 3.4`. CI runs a single Ruby 3.4 job on
  the self-hosted fleet, whose runner image carries 3.4.9; support for 3.3 is
  unverified and the gemspec excludes it.

## [0.3.0]

- Remove `Propitech/SeedUsesFactory`. The cop now ships in the `business_logic`
  gem (enable with `plugins: [business_logic]`) alongside its companion
  `Propitech/SeedUsesContainer`, which is the single home for the
  seed-authoring rules. Loading both plugins would otherwise define the cop
  twice. Repos that want the seed cops should add the `business_logic` plugin;
  `rubocop-propitech` keeps the view-layer cop (`Propitech/NoViewAssembly`).

## [0.2.0]

- Add `Propitech/SeedUsesFactory`: enforce that seed data is built with
  FactoryBot factories and traits. Flags a hand-rolled model create (a constant
  receiver `.create` / `.create!`, allowing `FactoryBot.create` /
  `FactoryGirl.create`) and a `Commands::…` business-logic command invocation,
  scoped to `db/seeds.rb` and `db/seeds/**/*.rb`.

## [0.1.0]

- Initial release.
- Add `Propitech/NoViewAssembly`: keep data or object assembly out of view
  templates. Flags instantiating a non-`Component` / non-`Form` constant,
  running an ActiveRecord query, or capturing a lambda in a local, inside
  `app/views`. Reached through erb_lint's Rubocop linter so it lints ERB.
