# dart-dedupe

An agent skill for finding and removing duplicated Dart code, by Kevin
Moore. `SKILL.md` is copied unchanged from
[kevmoo/analytica.dart](https://github.com/kevmoo/analytica.dart/tree/dedupe-v0.1.0/skills/dart-dedupe),
tag `dedupe-v0.1.0`. `LICENSE` is that package's licence.

dedupe is a dev dependency of the root `pubspec.yaml`, so the skill's
`dart run dedupe` works from the repository root; `melos run duplication`
runs it with this project's options. The skill goes with the dedupe version
that the root `pubspec.yaml` pins. When the version there changes, copy
`SKILL.md` again from the matching tag.

Where the skill and this project differ, `AGENTS.md` says which one to
follow.
