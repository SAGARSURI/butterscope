# butterscope_test

The one-line attach for integration tests. Add it as a dev dependency and
call `attachButterscope()` at the top of a test file's `main`:

```dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  attachButterscope();
  // testWidgets(...) as before
}
```

It sets the `benchmarkLive` frame policy, records every frame of the run,
attributes frames to the test that produced them, and prints the report
after the last test as `BSCOPE-REPORT` lines. The report's schema is
provisional until M7.

Spans and episodes arrive later in M5.
