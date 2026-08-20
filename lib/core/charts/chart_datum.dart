import 'package:flutter/material.dart';

/// A single labeled data point shared by all chart painters/widgets in
/// `lib/core/charts/`.
///
/// [color] is an optional per-datum override; painters that don't receive
/// an explicit color fall back to cycling through a default palette.
class ChartDatum {
  const ChartDatum({
    required this.label,
    required this.value,
    this.color,
  });

  /// Human-readable label shown on axes / legends (e.g. category name).
  final String label;

  /// Numeric value this datum represents.
  final double value;

  /// Optional explicit color for this datum. When null, the consuming
  /// painter/widget cycles through its default palette instead.
  final Color? color;
}
