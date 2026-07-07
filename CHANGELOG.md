# Changelog

## [Unreleased]

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
