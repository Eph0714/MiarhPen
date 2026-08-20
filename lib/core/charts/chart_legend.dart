import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import 'chart_datum.dart';

/// Default palette cycled through when a [ChartDatum] has no explicit
/// [ChartDatum.color] and the caller supplies no override palette.
const List<Color> _defaultLegendPalette = [
  AppColors.primary,
  AppColors.income,
  AppColors.transfer,
  AppColors.liability,
  AppColors.expense,
];

/// Compact legend for chart widgets: a colored dot + label + formatted
/// currency value per [ChartDatum], wrapped to fit within a card.
class ChartLegend extends StatelessWidget {
  const ChartLegend({
    required this.data,
    this.colors,
    super.key,
  });

  /// Data points to render, one row each.
  final List<ChartDatum> data;

  /// Optional fallback palette, cycled for data points without an explicit
  /// [ChartDatum.color]. Defaults to the standard chart palette.
  final List<Color>? colors;

  Color _colorFor(int index) {
    final datum = data[index];
    if (datum.color != null) return datum.color!;
    final palette = (colors != null && colors!.isNotEmpty)
        ? colors!
        : _defaultLegendPalette;
    return palette[index % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: [
        for (var i = 0; i < data.length; i++)
          _LegendRow(
            color: _colorFor(i),
            label: data[i].label,
            value: data[i].value,
          ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          CurrencyFormatter.format(value),
          style: textTheme.bodyMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
