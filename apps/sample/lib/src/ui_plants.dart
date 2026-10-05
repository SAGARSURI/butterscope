import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Planted UI-thread work, given the context of the screen it runs on.
typedef PlantedWork = void Function(BuildContext context);

/// Runs [work] on every event of a periodic stream while [active], as a
/// socket listener decoding each message would.
///
/// The work starts after a frame was requested. On Android it shows as UI
/// time, because the next frame waits for it (decision record 0001). On
/// iOS the vsync callback waits for it too, so it shows as missed vsyncs
/// (decision record 0002).
class ListenerWorkPlant extends StatefulWidget {
  const new({
    required this.active,
    required this.work,
    this.period = const Duration(milliseconds: 50),
    super.key,
  });

  final bool active;
  final PlantedWork work;

  /// How often the stream emits. **(open, M4: tuned per platform.)**
  final Duration period;

  @override
  State<ListenerWorkPlant> createState() => _ListenerWorkPlantState();
}

class _ListenerWorkPlantState extends State<ListenerWorkPlant> {
  StreamSubscription<int>? _subscription;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(ListenerWorkPlant oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _sync() {
    if (widget.active && _subscription == null) {
      _subscription = Stream.periodic(
        widget.period,
        (count) => count,
      ).listen(_onEvent);
    } else if (!widget.active && _subscription != null) {
      unawaited(_subscription!.cancel());
      _subscription = null;
    }
  }

  void _onEvent(int _) {
    if (mounted) widget.work(context);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Runs [work] in a post-frame callback after every frame while [active].
///
/// The work runs after the frame was stamped as built and before the next
/// one is requested, so it should show only as missed vsyncs (decision
/// record 0001).
class PostFrameWorkPlant extends StatefulWidget {
  const new({required this.active, required this.work, super.key});

  final bool active;
  final PlantedWork work;

  @override
  State<PostFrameWorkPlant> createState() => _PostFrameWorkPlantState();
}

class _PostFrameWorkPlantState extends State<PostFrameWorkPlant> {
  var _scheduled = false;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(PostFrameWorkPlant oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  void _schedule() {
    if (!widget.active || _scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || !widget.active) return;
      widget.work(context);
      _schedule();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
