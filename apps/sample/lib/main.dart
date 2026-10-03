import 'package:flutter/material.dart';

void main() {
  runApp(const SampleApp());
}

/// Placeholder until the calibration screen (M2) and sample screens (M4).
class SampleApp extends StatelessWidget {
  /// Creates the sample app.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('Butterscope sample'))),
    );
  }
}
