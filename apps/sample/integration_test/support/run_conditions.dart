// The conditions a probe run records next to its windows, shared by M2's
// and M4's probes.

import 'package:flutter/foundation.dart';

/// The build mode this run was compiled in.
String get buildMode {
  if (kReleaseMode) return 'release';
  if (kProfileMode) return 'profile';
  return 'debug';
}

/// Whether the run turns semantics on, from `BUTTERSCOPE_SEMANTICS` (`on`
/// or `off`, default `off`).
///
/// `testWidgets` turns semantics on unless told otherwise, and semantics
/// cost frames: DESIGN.md keeps it open (M6) whether observed tests turn it
/// off or record it with the flow. The probes default to off, so a run
/// measures the screen, and record which one they ran with.
bool semanticsFromEnvironment() {
  const value = String.fromEnvironment(
    'BUTTERSCOPE_SEMANTICS',
    defaultValue: 'off',
  );
  return switch (value) {
    'on' => true,
    'off' => false,
    _ => throw ArgumentError.value(value, 'BUTTERSCOPE_SEMANTICS'),
  };
}
