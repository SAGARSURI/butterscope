import 'dart:convert';

import 'package:butterscope_test/src/report_writer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prints the JSON in numbered chunks a reader can join', () {
    final lines = <String>[];
    final json = {'name': 'open detail', 'frames': 120};
    // {"name":"open detail","frames":120} is 35 characters: chunks of 10,
    // 10, 10 and 5.
    ReportWriter(lines.add, chunkLength: 10).write(json, runId: 42);

    expect(lines, hasLength(4));
    expect(lines.first, 'BSCOPE-REPORT 42 1 4 {"name":"o');
    expect(lines.last, 'BSCOPE-REPORT 42 4 4 :120}');
    final chunks = [
      for (final line in lines) line.split(' ').skip(4).join(' '),
    ];
    expect(jsonDecode(chunks.join()), json);
  });
}
