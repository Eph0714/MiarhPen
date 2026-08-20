import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/date_range_presets.dart';
import '../../application/report_filters.dart';

/// Horizontal chip row for picking a [ReportDateFilter]'s preset, plus
/// from/to date-picker fields that appear when [DateRangePreset.custom] is
/// selected.
class DateFilterBar extends StatelessWidget {
  const DateFilterBar({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final ReportDateFilter value;
  final ValueChanged<ReportDateFilter> onChanged;

  Future<void> _pickDate(BuildContext context, {required bool isFrom}) async {
    final initial =
        (isFrom ? value.customFrom : value.customTo) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    onChanged(
      isFrom
          ? value.copyWith(customFrom: picked)
          : value.copyWith(customTo: picked),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final preset in DateRangePreset.values)
                ChoiceChip(
                  label: Text(preset.label),
                  selected: value.preset == preset,
                  onSelected: (_) => onChanged(value.copyWith(preset: preset)),
                ),
            ],
          ),
        ),
        if (value.preset == DateRangePreset.custom) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(context, isFrom: true),
                  child: Text(
                    value.customFrom == null
                        ? 'From'
                        : DateFormatter.short(value.customFrom!),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(context, isFrom: false),
                  child: Text(
                    value.customTo == null
                        ? 'To'
                        : DateFormatter.short(value.customTo!),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
