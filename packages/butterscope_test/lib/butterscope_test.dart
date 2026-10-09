/// Attaches Butterscope to a Flutter integration test file with one line:
///
/// ```dart
/// void main() {
///   IntegrationTestWidgetsFlutterBinding.ensureInitialized();
///   attachButterscope();
///   // testWidgets(...) as before, with span(name, body) around each flow
///   // to gate
/// }
/// ```
///
/// Each test is also split into episodes, on input and animation, without
/// the test marking them. An app that adds `ButterscopeRouteObserver`, from
/// `package:butterscope`, to its navigator gets each episode tagged with the
/// page on top. See `docs/DESIGN.md` at the repository root.
library;

export 'package:butterscope_test/src/attach.dart' show attachButterscope, span;
