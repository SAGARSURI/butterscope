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

  test('never splits a character made of two code units', () {
    final lines = <String>[];
    // ["a😀"] is 7 code units: [ " a, the emoji's two (indices 3 and 4),
    // then " ]. A cut at 4 would split the emoji, so the first chunk stops
    // at 3 and the second takes the other 4.
    ReportWriter(lines.add, chunkLength: 4).write(['a😀'], runId: 7);

    expect(lines, ['BSCOPE-REPORT 7 1 2 ["a', 'BSCOPE-REPORT 7 2 2 😀"]']);
  });
}
