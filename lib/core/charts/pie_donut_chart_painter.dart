import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'chart_datum.dart';

/// Default palette cycled through for donut segments without an explicit
/// [ChartDatum.color]. Matches [BarChartPainter]'s default palette.
const List<Color> _defaultDonutPalette = [
  AppColors.primary,
  AppColors.income,
  AppColors.transfer,
  AppColors.liability,
  AppColors.expense,
];

/// Draws a donut (ring) chart: each [ChartDatum] becomes an arc sized
/// proportionally to its share of the total.
///
/// Handles an empty or all-zero [data] list by drawing a full light-gray
/// ring instead of dividing by zero.
class DonutChartPainter extends CustomPainter {
  DonutChartPainter({
    required this.data,
    this.colors,
    this.strokeWidthRatio = 0.4,
  });

  final List<ChartDatum> data;
  final List<Color>? colors;

  /// Ring thickness as a fraction of the outer radius (inner radius is
  /// `1 - strokeWidthRatio` of the outer radius, i.e. ~60% by default).
  final double strokeWidthRatio;

  static const double _gapDegrees = 2;

  Color _colorFor(int index) {
    if (data[index].color != null) return data[index].color!;
    final palette = (colors != null && colors!.isNotEmpty)
        ? colors!
        : _defaultDonutPalette;
    return palette[index % palette.length];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final outerRadius = math.min(size.width, size.height) / 2;
    if (outerRadius <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = outerRadius * strokeWidthRatio;
    final ringRadius = outerRadius - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: ringRadius);

    final total = data.fold<double>(0, (sum, d) => sum + d.value.abs());

    if (data.isEmpty || total <= 0) {
      final basePaint = Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, 0, 2 * math.pi, false, basePaint);
      return;
    }

    var startAngle = -math.pi / 2;
    final gapRad = _gapDegrees * math.pi / 180;

    for (var i = 0; i < data.length; i++) {
      final value = data[i].value.abs();
      if (value <= 0) continue;
      final sweep = (value / total) * 2 * math.pi;
      final drawSweep = data.length > 1 ? math.max(sweep - gapRad, 0.0) : sweep;

      final paint = Paint()
        ..color = _colorFor(i)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(rect, startAngle, drawSweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) {
    if (oldDelegate.data.length != data.length) return true;
    for (var i = 0; i < data.length; i++) {
      final a = oldDelegate.data[i];
      final b = data[i];
      if (a.label != b.label || a.value != b.value || a.color != b.color) {
        return true;
      }
    }
    return oldDelegate.colors != colors ||
        oldDelegate.strokeWidthRatio != strokeWidthRatio;
  }
}

/// Fixed-size donut chart widget wrapping [DonutChartPainter], with an
/// optional [centerLabel] rendered as text inside the donut hole (e.g. a
/// pre-formatted total: `"Total: ₱12,345.00"`).
///
/// Currency formatting is intentionally the caller's responsibility —
/// [DonutChartPainter] and this widget only ever handle plain strings, since
/// [CustomPainter] has no [BuildContext] to localize with.
class DonutChart extends StatelessWidget {
  const DonutChart({
    required this.data,
    this.colors,
    this.size = 160,
    this.centerLabel,
    super.key,
  });

  final List<ChartDatum> data;
  final List<Color>? colors;
  final double size;
  final String? centerLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              painter: DonutChartPainter(data: data, colors: colors),
              size: Size.square(size),
            ),
            if (centerLabel != null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  centerLabel!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
