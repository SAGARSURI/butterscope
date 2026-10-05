import 'dart:math';
import 'dart:ui' show FragmentProgram, FragmentShader, ImageFilter;

import 'package:flutter/widgets.dart';

/// Wraps [child] in [depth] layers that each need a save layer: an opacity
/// and an anti-aliased clip that saves a layer. When the child changes,
/// every layer is drawn again.
///
/// `slow_raster` wraps the calibration screen's box, which changes every
/// frame; `raster_clip` wraps each feed card, which moves as the feed
/// scrolls.
class SlowRasterPlant extends StatelessWidget {
  const new({
    required this.child,
    required this.depth,
    required this.fade,
    super.key,
  });

  final Widget child;
  final int depth;

  /// The opacity of the whole stack, so a deep stack does not hide [child].
  /// Each layer gets fade^(1/depth), at most 254/255: at 255 an opacity has
  /// nothing to apply. Alpha has 8 bits, so a stack deep enough to need the
  /// cap shows at (254/255)^depth, fainter than [fade]: 0.25 for 350 layers.
  final double fade;

  @override
  Widget build(BuildContext context) {
    final opacity = min(pow(fade, 1 / depth).toDouble(), 254 / 255);
    var layered = child;
    for (var i = 0; i < depth; i++) {
      layered = Opacity(
        opacity: opacity,
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

/// [layers] backdrop blurs of [sigma], one over the other, over everything
/// painted before them, filling the space they are given.
///
/// `backdrop_blur` fills the calibration screen; `gpu_blur` fills the
/// detail page's header.
class BackdropBlurPlant extends StatelessWidget {
  const new({required this.layers, required this.sigma, super.key});

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
class GpuHeavyPlant extends StatefulWidget {
  const new({
    required this.turns,
    required this.iterations,
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
