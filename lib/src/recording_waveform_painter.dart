import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Paints a live amplitude waveform that scrolls right-to-left.
///
/// Each entry in [amplitudes] is a normalised value in [0.0, 1.0]. The newest
/// sample is drawn at the right edge; older samples scroll left and fade.
class RecordingWaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final Color barColor;

  const RecordingWaveformPainter({
    required this.amplitudes,
    required this.barColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) return;

    const barWidth = 4.0;
    const barGap = 2.0;
    const step = barWidth + barGap;
    const minBarHeight = 3.5;
    const cornerRadius = 2.0;

    final maxBars = (size.width / step).floor();
    final sampleCount = amplitudes.length;
    final startIndex = sampleCount > maxBars ? sampleCount - maxBars : 0;
    final visibleCount = sampleCount - startIndex;

    final paint = Paint()..style = PaintingStyle.fill;
    final centerY = size.height / 2;

    for (var i = visibleCount - 1; i >= 0; i--) {
      final offsetFromEnd = visibleCount - 1 - i;
      final x = size.width - (offsetFromEnd * step) - barWidth;
      if (x < 0) break;

      final sample = amplitudes[startIndex + i].clamp(0.0, 1.0);
      final eased = Curves.easeOutCubic.transform(sample);
      final ageFactor = (1 - (offsetFromEnd / maxBars)).clamp(0.22, 1.0);
      final opacity = (0.25 + (ageFactor * 0.75)).clamp(0.0, 1.0);
      final barHeight = minBarHeight + eased * (size.height - minBarHeight);
      final top = centerY - (barHeight / 2);

      paint.color = barColor.withValues(alpha: opacity);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, top, barWidth, barHeight),
          const Radius.circular(cornerRadius),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(RecordingWaveformPainter oldDelegate) {
    return oldDelegate.barColor != barColor ||
        !listEquals(oldDelegate.amplitudes, amplitudes);
  }
}
