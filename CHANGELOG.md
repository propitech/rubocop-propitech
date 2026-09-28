# Changelog

## [Unreleased]

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
