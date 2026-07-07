# Changelog

## [Unreleased]

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
