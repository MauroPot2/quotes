import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// Shows one non-modal error at a time, above the current route or dialog.
void showErrorPopup(BuildContext context, String message) {
  if (!context.mounted) return;
  _ErrorPopupHost.show(context, message);
}

abstract final class _ErrorPopupHost {
  static OverlayEntry? _current;

  static void show(BuildContext context, String message) {
    final overlay = Overlay.of(context, rootOverlay: true);
    if (_current case final previous?) _remove(previous);
    late final OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => _ErrorPopup(
      message: message,
      onClose: () => _remove(entry),
      onDispose: () {
        if (identical(_current, entry)) _current = null;
      },
    ));
    _current = entry;
    overlay.insert(entry);
  }

  static void _remove(OverlayEntry entry) {
    if (!identical(_current, entry)) return;
    _current = null;
    entry.remove();
    entry.dispose();
  }
}

class _ErrorPopup extends StatefulWidget {
  const _ErrorPopup({required this.message, required this.onClose, required this.onDispose});
  final String message;
  final VoidCallback onClose;
  final VoidCallback onDispose;

  @override
  State<_ErrorPopup> createState() => _ErrorPopupState();
}

class _ErrorPopupState extends State<_ErrorPopup> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 3), widget.onClose);
  }

  @override
  void dispose() {
    _timer.cancel();
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Align(alignment: Alignment.topCenter, child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
            duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(offset: Offset(0, -12 * (1 - value)), child: child),
            ),
            child: Semantics(liveRegion: true, container: true, child: Material(
              color: colors.errorContainer,
              elevation: 8,
              shadowColor: colors.shadow.withValues(alpha: .24),
              borderRadius: BorderRadius.circular(18),
              child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 8, 12), child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: const EdgeInsets.only(top: 3), child: Icon(Icons.error_outline_rounded, color: colors.onErrorContainer)),
                  const SizedBox(width: 12),
                  Expanded(child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: SingleChildScrollView(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Attenzione', style: TextStyle(color: colors.onErrorContainer, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 3),
                        Text(widget.message, style: TextStyle(color: colors.onErrorContainer)),
                      ],
                    )),
                  )),
                  IconButton(tooltip: 'Chiudi avviso', onPressed: widget.onClose,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close, color: colors.onErrorContainer)),
                ],
              )),
            )),
          ),
        )),
      )),
    );
  }
}
