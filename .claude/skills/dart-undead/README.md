# dart-undead

An agent skill for finding and removing dead Dart code, by Kevin Moore.
`SKILL.md` is copied unchanged from
[kevmoo/analytica.dart](https://github.com/kevmoo/analytica.dart/tree/6e927f0035ebdc44d1d7f60e2bd6d6a19d36d64a/skills/dart-undead),
commit `6e927f0`, the commit the root `pubspec.yaml` pins undead to. The
latest release, undead 0.1.1, no longer compiles; the comment there says
why. `LICENSE` is that package's licence.

The skill's commands use `dart run undead@^0.1.1`, that broken release; run
`melos run dead-code`, or `dart run undead` from the repository root,
instead. When the undead pin in the root `pubspec.yaml` changes, copy
`SKILL.md` again from the same release or commit.

Where the skill and this project differ, `AGENTS.md` says which one to
follow.
