import 'dart:io';

/// Fails any real HTTP call, so a stray request fails loudly instead of
/// adding random latency to a measured flow (DESIGN section 7.5).
class NoNetworkHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw UnsupportedError(
      'The sample app makes no network calls; its data is faked.',
    );
  }
}
