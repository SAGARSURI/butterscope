# dart-undead

An agent skill for finding and removing dead Dart code, by Kevin Moore.
`SKILL.md` is copied unchanged from
[kevmoo/analytica.dart](https://github.com/kevmoo/analytica.dart/tree/6e927f0035ebdc44d1d7f60e2bd6d6a19d36d64a/skills/dart-undead),
commit `6e927f0`, the commit `tool/analytica.sh` runs undead from. The latest
release, undead 0.1.1, no longer compiles; the comment in that script says
why. `LICENSE` is that package's licence.

The skill's commands use `dart run undead@^0.1.1`; run `melos run dead-code`
instead. When the undead source in `tool/analytica.sh` changes, copy
`SKILL.md` again from the same release or commit.

Where the skill and this project differ, `AGENTS.md` says which one to
follow.
