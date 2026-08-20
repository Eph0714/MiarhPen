import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'chart_datum.dart';

/// Draws a single-series line chart for a list of [ChartDatum], with
/// straight-line segments, filled circle markers, and a light gradient
/// fill under the line.
///
/// Handles 0, 1, and many points without throwing: an empty list draws
/// just the baseline/gridlines (no "No data" label), a single point draws
/// only its marker.
class LineChartPainter extends CustomPainter {
  LineChartPainter({
    required this.data,
    this.lineColor = AppColors.primary,
    this.textStyle,
  });

  final List<ChartDatum> data;
  final Color lineColor;
  final TextStyle? textStyle;

  static const double _axisLabelHeight = 20;
  static const double _markerRadius = 3.5;
  static const int _gridLineCount = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final chartHeight = size.height - _axisLabelHeight;
    if (chartHeight <= 0 || size.width <= 0) return;

    final gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;

    for (var i = 1; i <= _gridLineCount; i++) {
      final y = chartHeight * i / (_gridLineCount + 1);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    canvas.drawLine(
      Offset(0, chartHeight),
      Offset(size.width, chartHeight),
      gridPaint,
    );

    if (data.isEmpty) {
      // Nothing to plot yet — baseline/gridlines already drawn above, no
      // "No data" label needed.
      return;
    }

    final maxValue = data.fold<double>(
      0,
      (max, d) => d.value.abs() > max ? d.value.abs() : max,
    );

    if (maxValue <= 0) {
      // All zero values: draw markers on the baseline (avoids div-by-zero).
      final points = _pointPositions(size.width, chartHeight, maxValue: 1);
      _drawMarkersAndLabels(canvas, points, chartHeight);
      return;
    }

    final points = _pointPositions(size.width, chartHeight, maxValue: maxValue);

    if (points.length > 1) {
      final fillPath = Path()..moveTo(points.first.dx, chartHeight);
      for (final p in points) {
        fillPath.lineTo(p.dx, p.dy);
      }
      fillPath.lineTo(points.last.dx, chartHeight);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = _gradientShader(size.width, chartHeight, lineColor);
      canvas.drawPath(fillPath, fillPaint);

      final linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        linePath.lineTo(p.dx, p.dy);
      }
      final linePaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(linePath, linePaint);
    }

    _drawMarkersAndLabels(canvas, points, chartHeight);
  }

  Shader _gradientShader(double width, double height, Color color) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.0)],
    ).createShader(Rect.fromLTWH(0, 0, width, height));
  }

  List<Offset> _pointPositions(
    double width,
    double chartHeight, {
    required double maxValue,
  }) {
    final n = data.length;
    if (n == 1) {
      return [
        Offset(
          width / 2,
          chartHeight - (data[0].value.abs() / maxValue) * chartHeight,
        ),
      ];
    }
    final step = width / (n - 1);
    return [
      for (var i = 0; i < n; i++)
        Offset(
          i * step,
          chartHeight - (data[i].value.abs() / maxValue) * chartHeight,
        ),
    ];
  }

  void _drawMarkersAndLabels(
    Canvas canvas,
    List<Offset> points,
    double chartHeight,
  ) {
    final markerPaint = Paint()..color = lineColor;
    final markerBorderPaint = Paint()
      ..color = AppColors.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final n = data.length;
    final skipLabels = n > 6;

    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], _markerRadius, markerPaint);
      canvas.drawCircle(points[i], _markerRadius, markerBorderPaint);

      if (!skipLabels || i.isEven) {
        _drawAxisLabel(canvas, data[i].label, points[i].dx, chartHeight + 2);
      }
    }
  }

  void _drawAxisLabel(Canvas canvas, String label, double centerX, double top) {
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
    tp.layout(maxWidth: 60);
    tp.paint(canvas, Offset(centerX - tp.width / 2, top));
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) {
    if (oldDelegate.data.length != data.length) return true;
    for (var i = 0; i < data.length; i++) {
      final a = oldDelegate.data[i];
      final b = data[i];
      if (a.label != b.label || a.value != b.value || a.color != b.color) {
        return true;
      }
    }
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.textStyle != textStyle;
  }
}

/// Convenience widget wrapping [LineChartPainter] in a fixed-height
/// [CustomPaint].
class LineChart extends StatelessWidget {
  const LineChart({
    required this.data,
    this.lineColor = AppColors.primary,
    this.height = 180,
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    super.key,
  });

  final List<ChartDatum> data;
  final Color lineColor;
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
          painter: LineChartPainter(data: data, lineColor: lineColor),
          size: Size.infinite,
        ),
      ),
    );
  }
}
