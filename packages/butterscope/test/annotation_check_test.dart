import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deliberately fails to check CI annotations', () {
    expect(1 + 1, 3);
  });
}
