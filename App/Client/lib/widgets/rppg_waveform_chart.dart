import 'package:flutter/material.dart';

/// 서버 테스트 페이지(`main.py` HTML)의 `drawRppg`와 동일한 스케일링으로
/// BVP/rPPG 시계열을 선 그래프로 그린다.
class RppgWaveformChart extends StatelessWidget {
  final List<double> samples;
  final Color lineColor;
  final Color gridColor;

  /// 지정 시 X축을 고정 슬롯 수로 두고, 최신 샘플을 오른쪽에 맞춘다(슬라이딩).
  final int? fixedWindowSize;

  const RppgWaveformChart({
    super.key,
    required this.samples,
    this.lineColor = const Color(0xFF007BFF),
    this.gridColor = const Color(0xFFE8EEF2),
    this.fixedWindowSize,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RppgWaveformPainter(
        samples: samples,
        lineColor: lineColor,
        gridColor: gridColor,
        fixedWindowSize: fixedWindowSize,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _RppgWaveformPainter extends CustomPainter {
  final List<double> samples;
  final Color lineColor;
  final Color gridColor;
  final int? fixedWindowSize;

  _RppgWaveformPainter({
    required this.samples,
    required this.lineColor,
    required this.gridColor,
    this.fixedWindowSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bg = Paint()..color = Colors.white;
    canvas.drawRect(rect, bg);

    if (samples.length < 2) return;

    double minVal = samples.first;
    double maxVal = samples.first;
    for (final v in samples) {
      if (v < minVal) minVal = v;
      if (v > maxVal) maxVal = v;
    }
    final range = (maxVal - minVal).abs();
    final denom = range > 1e-12 ? range : 1.0;

    const pad = 4.0;
    final w = size.width - 2 * pad;
    final h = size.height - 2 * pad;
    if (w <= 0 || h <= 0) return;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final midY = pad + h / 2;
    canvas.drawLine(Offset(pad, midY), Offset(pad + w, midY), grid);

    final path = Path();
    final slotCount = fixedWindowSize != null && fixedWindowSize! >= 2
        ? fixedWindowSize!
        : samples.length;
    final xDenom = slotCount > 1 ? (slotCount - 1) : 1.0;
    final startSlot =
        fixedWindowSize != null ? (slotCount - samples.length).clamp(0, slotCount - 1) : 0;

    for (var i = 0; i < samples.length; i++) {
      final slot = fixedWindowSize != null ? startSlot + i : i;
      final x = pad + (slot / xDenom) * w;
      final norm = (samples[i] - minVal) / denom;
      final y = pad + h - norm * h;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final stroke = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _RppgWaveformPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.fixedWindowSize != fixedWindowSize;
  }
}
