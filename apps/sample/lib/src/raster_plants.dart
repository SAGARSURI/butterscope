import 'dart:ui' show FragmentProgram, FragmentShader, ImageFilter;

import 'package:flutter/widgets.dart';

/// Wraps [child] in [depth] layers that each need a save layer: an opacity
/// and an anti-aliased clip that saves a layer. The child changes every
/// frame, so every layer is drawn again each frame.
///
/// The depth drops frames on the Galaxy S24 but not on the iPhone 17 Pro.
/// **(open, M4: tuned per platform.)**
class SlowRasterPlant extends StatelessWidget {
  const new({required this.child, this.depth = 40, super.key});

  final Widget child;
  final int depth;

  @override
  Widget build(BuildContext context) {
    var layered = child;
    for (var i = 0; i < depth; i++) {
      layered = Opacity(
        opacity: 0.98,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAliasWithSaveLayer,
          child: layered,
        ),
      );
    }
    return layered;
  }
}

/// [layers] full-screen backdrop blurs, one over the other, over everything
/// painted before them.
///
/// The layer count and blur radius drop frames on the Galaxy S24 but not on
/// the iPhone 17 Pro. **(open, M4: tuned per platform.)**
class BackdropBlurPlant extends StatelessWidget {
  const new({this.layers = 6, this.sigma = 40, super.key});

  final int layers;
  final double sigma;

  @override
  Widget build(BuildContext context) {
    final filter = ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < layers; i++)
          BackdropFilter(filter: filter, child: const SizedBox.expand()),
      ],
    );
  }
}

/// A full-screen fragment shader that runs a loop of [iterations] steps for
/// every pixel, redrawn as [turns] moves.
///
/// The raster thread records a single draw; the cost is GPU execution,
/// which `FrameTiming` does not include, though on both phones it showed as
/// raster time because the raster thread waits on the GPU. Draws nothing
/// until the shader has loaded, and throws if it fails to load, so a run
/// cannot measure a clean screen by mistake.
///
/// The iteration count suits the Galaxy S24 and is far too heavy for the
/// iPhone 17 Pro. **(open, M4: tuned per platform.)**
class GpuHeavyPlant extends StatefulWidget {
  const new({
    required this.turns,
    this.iterations = 500,
    this.loadProgram = _loadShader,
    super.key,
  });

  final Animation<double> turns;
  final int iterations;

  /// Loads the shader; a test can pass one that fails.
  final Future<FragmentProgram> Function() loadProgram;

  static Future<FragmentProgram> _loadShader() {
    return FragmentProgram.fromAsset('shaders/gpu_heavy.frag');
  }

  @override
  State<GpuHeavyPlant> createState() => _GpuHeavyPlantState();
}

class _GpuHeavyPlantState extends State<GpuHeavyPlant> {
  late final Future<FragmentProgram> _program = widget.loadProgram();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FragmentProgram>(
      future: _program,
      builder: (context, snapshot) {
        if (snapshot.error case final error?) {
          Error.throwWithStackTrace(
            error,
            snapshot.stackTrace ?? StackTrace.empty,
          );
        }
        final program = snapshot.data;
        if (program == null) return const SizedBox.expand();
        return CustomPaint(
          size: Size.infinite,
          painter: _ShaderPainter(
            shader: program.fragmentShader(),
            turns: widget.turns,
            iterations: widget.iterations,
          ),
        );
      },
    );
  }
}

class _ShaderPainter extends CustomPainter {
  new({required this.shader, required this.turns, required this.iterations})
    : super(repaint: turns);

  final FragmentShader shader;
  final Animation<double> turns;
  final int iterations;

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, turns.value * 6.28)
      ..setFloat(3, iterations.toDouble());
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_ShaderPainter oldDelegate) {
    return oldDelegate.iterations != iterations;
  }
}
