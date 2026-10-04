import 'dart:math' as math;

import 'package:butterscope_sample/src/busy_work.dart';
import 'package:butterscope_sample/src/plant.dart';
import 'package:butterscope_sample/src/raster_plants.dart';
import 'package:butterscope_sample/src/ui_plants.dart';
import 'package:flutter/material.dart';

/// What the calibration screen shows.
enum CalibrationPhase {
  /// A box turns and slides without pause, so every frame changes.
  animated,

  /// Nothing on screen changes.
  still,
}

/// A screen with a predictable frame count, for measuring the recorder.
///
/// In the [CalibrationPhase.animated] phase a box turns and slides
/// constantly, and the [plant], if any, runs. In the
/// [CalibrationPhase.still] phase the box stops where it is and no plant
/// runs. A test sets the phase through [phase]; tapping the screen toggles
/// it by hand.
class CalibrationScreen extends StatefulWidget {
  const new({
    required this.plant,
    required this.phase,
    this.work = busyForPlantedWork,
    super.key,
  });

  final Plant plant;
  final ValueNotifier<CalibrationPhase> phase;

  /// The UI-thread work the decode plants run.
  final PlantedWork work;

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turns = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );

  @override
  void initState() {
    super.initState();
    widget.phase.addListener(_followPhase);
    _followPhase();
  }

  @override
  void dispose() {
    widget.phase.removeListener(_followPhase);
    _turns.dispose();
    super.dispose();
  }

  void _followPhase() {
    if (widget.phase.value == CalibrationPhase.animated) {
      _turns.repeat().ignore();
    } else {
      _turns.stop();
    }
  }

  void _toggle() {
    widget.phase.value = widget.phase.value == CalibrationPhase.animated
        ? CalibrationPhase.still
        : CalibrationPhase.animated;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: ValueListenableBuilder<CalibrationPhase>(
        valueListenable: widget.phase,
        builder: (context, phase, _) {
          final plant = phase == CalibrationPhase.animated
              ? widget.plant
              : Plant.none;
          return _buildScene(plant);
        },
      ),
    );
  }

  Widget _buildScene(Plant plant) {
    Widget box = _TurningBox(turns: _turns);
    if (plant == Plant.slowRaster) box = SlowRasterPlant(child: box);
    return ColoredBox(
      color: Colors.white,
      child: Stack(
        fit: StackFit.expand,
        children: [
          box,
          if (plant == Plant.gpuHeavy) GpuHeavyPlant(turns: _turns),
          if (plant == Plant.backdropBlur) const BackdropBlurPlant(),
          ListenerWorkPlant(
            active: plant == Plant.listenerDecode,
            work: widget.work,
          ),
          PostFrameWorkPlant(
            active: plant == Plant.postframeDecode,
            work: widget.work,
          ),
        ],
      ),
    );
  }
}

class _TurningBox extends StatelessWidget {
  const new({required this.turns});

  final Animation<double> turns;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF2F2F2),
      child: AnimatedBuilder(
        animation: turns,
        builder: (context, child) {
          final angle = 2 * math.pi * turns.value;
          return Transform.translate(
            offset: Offset(100 * math.sin(angle), 0),
            child: Transform.rotate(angle: angle, child: child),
          );
        },
        child: const Center(
          child: SizedBox.square(
            key: Key('calibration-box'),
            dimension: 120,
            child: ColoredBox(color: Color(0xFFFF7A00)),
          ),
        ),
      ),
    );
  }
}
