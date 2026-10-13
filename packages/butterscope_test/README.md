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
attributes frames to the test that produced them, and prints a `start`
line before the first test and the report, with every frame, after the
last test. The lines and the report's fields are in
[`docs/report-schema.md`](../../docs/report-schema.md), proposed until
M7's gate.

Wrap each flow to gate in a named span, inside a test:

```dart
await span('feed scroll', () async {
  await tester.scrollUntilVisible(card, 400);
});
```

A span's frames are those its body produces. Spans are flat, and each name
is used once per run, so a baseline matches one span per name.

Each test is also split into episodes without marking them: a new
episode starts at a pointer event (a tap, drag or fling) after 300 ms
without one. Typing is not a pointer event, so it starts none. Episodes are
advisory and never gated, since the same test can split differently from
run to run.

To tag each episode with the page on top, add the observer from
`package:butterscope` to the app's `MaterialApp`, the root navigator. A
page change then starts an episode too, at the tap that opened the page,
and a page is named by its route's `RouteSettings.name`. Outside a test run the observer does nothing, so it
can stay in a release build.

```dart
MaterialApp(navigatorObservers: [ButterscopeRouteObserver()], ...)
```
