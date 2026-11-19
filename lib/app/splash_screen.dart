import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Brief branded introduction; the app starts loading underneath it.
class SplashScreen extends StatefulWidget {
  const SplashScreen({required this.child, super.key});

  final Widget child;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _finished = true);
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (MediaQuery.disableAnimationsOf(context)) {
        _finished = true;
      } else {
        _controller.forward();
      }
    } else if (!_finished && MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _finished = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ExcludeSemantics(
        excluding: !_finished,
        child: AbsorbPointer(absorbing: !_finished, child: widget.child),
      ),
      if (!_finished)
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final reveal = Curves.easeOutCubic.transform((t / .42).clamp(0.0, 1.0));
            final words = Curves.easeOutCubic.transform(((t - .19) / .28).clamp(0.0, 1.0));
            final fade = 1 - Curves.easeInOut.transform(((t - .82) / .18).clamp(0.0, 1.0));
            return Opacity(
              opacity: fade,
              child: Semantics(
                label: 'Avvio di Preventivo',
                child: ExcludeSemantics(
                  child: _SplashArtwork(progress: t, reveal: reveal, words: words),
                ),
              ),
            );
          },
        ),
    ],
  );
}

class _SplashArtwork extends StatelessWidget {
  const _SplashArtwork({required this.progress, required this.reveal, required this.words});

  final double progress;
  final double reveal;
  final double words;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF08060B),
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -.24),
          radius: .85,
          colors: [Color(0xFF321027), Color(0xFF100914), Color(0xFF08060B)],
          stops: [0, .47, 1],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final size = math.min(260.0, math.min(constraints.maxWidth * .72, constraints.maxHeight * .44));
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: size,
                  height: size,
                  child: CustomPaint(
                    painter: _OrbitPainter(progress),
                    child: Center(
                      child: Opacity(
                        opacity: reveal,
                        child: Transform.scale(
                          scale: .82 + .18 * reveal,
                          child: Container(
                            width: size * .62,
                            height: size * .62,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(size * .145),
                              boxShadow: [BoxShadow(color: const Color(0xFFB40E58).withValues(alpha: .26 * reveal), blurRadius: 42, spreadRadius: 2)],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(size * .145),
                              child: Image.asset('assets/icon/app_icon.png', fit: BoxFit.cover),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: size * .08),
                Opacity(
                  opacity: words,
                  child: Transform.translate(
                    offset: Offset(0, 12 * (1 - words)),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('PREVENTIVO', textAlign: TextAlign.center, style: TextStyle(
                          color: Colors.white, fontSize: 21, fontWeight: FontWeight.w600,
                          letterSpacing: 5, decoration: TextDecoration.none,
                        )),
                        SizedBox(height: 12),
                        Text('LE TUE IDEE, IL TUO VALORE', textAlign: TextAlign.center, style: TextStyle(
                          color: Color(0xFFC69AAC), fontSize: 9, fontWeight: FontWeight.w500,
                          letterSpacing: 2.1, decoration: TextDecoration.none,
                        )),
                      ],
                    ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    ),
  );
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * .45;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final ring = Paint()..style = PaintingStyle.stroke..strokeWidth = .8
      ..color = const Color(0xFFCC87A7).withValues(alpha: .17);
    canvas.drawCircle(center, radius, ring);
    canvas.drawCircle(center, radius * .87, ring..color = const Color(0xFFCC87A7).withValues(alpha: .08));

    final arc = Paint()..style = PaintingStyle.stroke..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(colors: [Color(0x00E8498C), Color(0xFFE8498C), Color(0xFFFFC1D9)])
          .createShader(rect);
    final sweep = Curves.easeOutCubic.transform((progress / .55).clamp(0.0, 1.0)) * math.pi * 1.25;
    canvas.drawArc(rect, -math.pi * .72 + progress * .7, sweep, false, arc);

    final angle = -math.pi * .72 + progress * .7 + sweep;
    final dot = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    canvas.drawCircle(dot, 3, Paint()..color = const Color(0xFFFFC1D9).withValues(alpha: .9));
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) => oldDelegate.progress != progress;
}
