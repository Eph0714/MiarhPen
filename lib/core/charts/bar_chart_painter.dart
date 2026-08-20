import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'chart_datum.dart';

/// Default palette cycled through for bars without an explicit
/// [ChartDatum.color].
const List<Color> _defaultBarPalette = [
  AppColors.primary,
  AppColors.income,
  AppColors.transfer,
  AppColors.liability,
  AppColors.expense,
];

/// Draws a simple vertical bar chart for a list of [ChartDatum].
///
/// Handles empty and all-zero data gracefully by drawing a flat baseline
/// instead of dividing by zero (no "No data" label — an empty chart on a
/// fresh account/period isn't an error state worth calling out).
class BarChartPainter extends CustomPainter {
  BarChartPainter({required this.data, this.colors, this.textStyle});

  final List<ChartDatum> data;
  final List<Color>? colors;
  final TextStyle? textStyle;

  static const double _axisLabelHeight = 20;
  static const double _barGap = 8;
  static const double _cornerRadius = 4;
  static const int _gridLineCount = 2;

  Color _colorFor(int index) {
    if (data[index].color != null) return data[index].color!;
    final palette = (colors != null && colors!.isNotEmpty)
        ? colors!
        : _defaultBarPalette;
    return palette[index % palette.length];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final chartHeight = size.height - _axisLabelHeight;
    if (chartHeight <= 0 || size.width <= 0) return;

    final gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;

    // Gridlines for scale reference.
    for (var i = 1; i <= _gridLineCount; i++) {
      final y = chartHeight * i / (_gridLineCount + 1);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (data.isEmpty) {
      // Nothing to plot yet — just the flat baseline below, no "No data"
      // label; an empty chart on a fresh account/period isn't an error
      // state worth calling out with text.
      canvas.drawLine(
        Offset(0, chartHeight),
        Offset(size.width, chartHeight),
        gridPaint,
      );
      return;
    }

    final maxValue = data.fold<double>(
      0,
      (max, d) => d.value.abs() > max ? d.value.abs() : max,
    );

    // Baseline.
    canvas.drawLine(
      Offset(0, chartHeight),
      Offset(size.width, chartHeight),
      gridPaint,
    );

    if (maxValue <= 0) {
      // All-zero data (e.g. no income/expense recorded yet this period) —
      // baseline is already drawn above; no "No data" label.
      return;
    }

    final n = data.length;
    final totalGap = _barGap * (n + 1);
    final barWidth = ((size.width - totalGap) / n).clamp(1.0, double.infinity);

    // Skip every-other label when there are more than 6 bars, to reduce
    // overlap.
    final skipLabels = n > 6;

    for (var i = 0; i < n; i++) {
      final datum = data[i];
      final value = datum.value.abs();
      final barHeight = (value / maxValue) * chartHeight;
      final left = _barGap + i * (barWidth + _barGap);
      final top = chartHeight - barHeight;

      final rect = Rect.fromLTWH(left, top, barWidth, barHeight);
      final rrect = RRect.fromRectAndCorners(
        rect,
        topLeft: const Radius.circular(_cornerRadius),
        topRight: const Radius.circular(_cornerRadius),
      );

      final paint = Paint()..color = _colorFor(i);
      canvas.drawRRect(rrect, paint);

      if (!skipLabels || i.isEven) {
        _drawAxisLabel(
          canvas,
          datum.label,
          left + barWidth / 2,
          chartHeight + 2,
          barWidth + _barGap,
        );
      }
    }
  }

  void _drawAxisLabel(
    Canvas canvas,
    String label,
    double centerX,
    double top,
    double maxWidth,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style:
            textStyle ??
            const TextStyle(color: AppColors.textSecondary, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    );
    tp.layout(maxWidth: maxWidth);
    tp.paint(canvas, Offset(centerX - tp.width / 2, top));
  }

  @override
  bool shouldRepaint(covariant BarChartPainter oldDelegate) {
    if (oldDelegate.data.length != data.length) return true;
    for (var i = 0; i < data.length; i++) {
      final a = oldDelegate.data[i];
      final b = data[i];
      if (a.label != b.label || a.value != b.value || a.color != b.color) {
        return true;
      }
    }
    return oldDelegate.colors != colors || oldDelegate.textStyle != textStyle;
  }
}

/// Convenience widget wrapping [BarChartPainter] in a fixed-height
/// [CustomPaint], one vertical bar per [ChartDatum], auto-scaled to the
/// max value.
class BarChart extends StatelessWidget {
  const BarChart({
    required this.data,
    this.colors,
    this.height = 180,
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    super.key,
  });

  final List<ChartDatum> data;
  final List<Color>? colors;
  final double height;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: BarChartPainter(data: data, colors: colors),
          size: Size.infinite,
        ),
      ),
    );
  }
}
