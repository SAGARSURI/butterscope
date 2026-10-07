/// Attaches Butterscope to a Flutter integration test file with one line:
///
/// ```dart
/// void main() {
///   IntegrationTestWidgetsFlutterBinding.ensureInitialized();
///   attachButterscope();
///   // testWidgets(...) as before
/// }
/// ```
///
/// Spans and episodes arrive later in M5.
/// See `docs/DESIGN.md` at the repository root.
library;

export 'package:butterscope_test/src/attach.dart' show attachButterscope;
