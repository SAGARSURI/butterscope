// A test file that opens a span without attaching first.

import 'package:butterscope_test/butterscope_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a span before attachButterscope fails', (tester) async {
    var ran = false;
    await expectLater(
      span('feed scroll', () async => ran = true),
      throwsStateError,
    );
    expect(ran, isFalse);
  });
}
