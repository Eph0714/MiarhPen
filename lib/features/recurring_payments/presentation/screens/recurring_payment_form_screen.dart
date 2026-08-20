import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/platform/ringtone_picker_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../../accounts/application/accounts_provider.dart';
import '../../../categories/application/categories_provider.dart';
import '../../application/recurring_payments_provider.dart';
import '../../domain/recurring_payment.dart';

/// Create/edit form for a [RecurringPayment] schedule, e.g. "Payment of
/// Housing Loan, every 6 of the month, 08:00 AM - 05:00 PM, Unpaid". Pass
/// [existing] to edit; leave it null to create a new schedule.
class RecurringPaymentFormScreen extends ConsumerStatefulWidget {
  const RecurringPaymentFormScreen({
    super.key,
    this.existing,
    required this.onSaved,
    required this.onCancel,
  });

  final RecurringPayment? existing;
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  @override
  ConsumerState<RecurringPaymentFormScreen> createState() =>
      _RecurringPaymentFormScreenState();
}

class _RecurringPaymentFormScreenState
    extends ConsumerState<RecurringPaymentFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;

  late int _dayOfMonth;
  int? _accountId;
  int? _expenseCategoryId;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  late RecurringPaymentStatus _status;

  late bool _alarmEnabled;
  String? _alarmSoundUri;
  String? _alarmSoundName;

  final _ringtonePicker = RingtonePickerService();

  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    _amountController = TextEditingController(
      text: existing?.amount?.toString() ?? '',
    );
    _dayOfMonth = existing?.dayOfMonth ?? 1;
    _accountId = existing?.accountId;
    _expenseCategoryId = existing?.expenseCategoryId;
    _startTime = existing?.startTime;
    _endTime = existing?.endTime;
    _status = existing?.status ?? RecurringPaymentStatus.unpaid;
    _alarmEnabled = existing?.alarmEnabled ?? false;
    _alarmSoundUri = existing?.alarmSoundUri;
    _alarmSoundName = existing?.alarmSoundName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial =
        (isStart ? _startTime : _endTime) ??
        const TimeOfDay(hour: 8, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return 'Not set';
    return time.format(context);
  }

  Future<void> _pickAlarmSound() async {
    final picked = await _ringtonePicker.pickAlarmSound(
      existingUri: _alarmSoundUri,
    );
    if (picked == null) return;
    setState(() {
      _alarmSoundUri = picked.uri;
      _alarmSoundName = picked.name;
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final controller = ref.read(recurringPaymentControllerProvider);
    try {
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim();
      final amount = double.tryParse(_amountController.text.trim());

      if (_isEditing) {
        await controller.save(
          widget.existing!.copyWith(
            name: name,
            description: description,
            amount: amount,
            accountId: _accountId,
            expenseCategoryId: _expenseCategoryId,
            dayOfMonth: _dayOfMonth,
            startTime: _startTime,
            endTime: _endTime,
            status: _status,
            alarmEnabled: _alarmEnabled,
            alarmSoundUri: _alarmSoundUri,
            alarmSoundName: _alarmSoundName,
            clearAlarmSound: _alarmSoundUri == null,
          ),
        );
      } else {
        await controller.create(
          name: name,
          description: description,
          amount: amount,
          accountId: _accountId,
          expenseCategoryId: _expenseCategoryId,
          dayOfMonth: _dayOfMonth,
          startTime: _startTime,
          endTime: _endTime,
          alarmEnabled: _alarmEnabled,
          alarmSoundUri: _alarmSoundUri,
          alarmSoundName: _alarmSoundName,
        );
      }
      if (!mounted) return;
      widget.onSaved();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(activeAccountsProvider);
    final expenseCategoriesAsync = ref.watch(expenseCategoriesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Recurring Payment' : 'New Recurring Payment',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onCancel,
        ),
      ),
      body: LoadingOverlay(
        visible: _saving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Payment Name',
                  hintText: 'e.g. Payment of Housing Loan',
                ),
                validator: (v) => Validators.required(v, fieldName: 'Name'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount (optional)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  return double.tryParse(v.trim()) == null
                      ? 'Enter a valid amount'
                      : null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<int>(
                initialValue: _dayOfMonth,
                decoration: const InputDecoration(labelText: 'Day of Month'),
                items: List.generate(31, (i) => i + 1)
                    .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _dayOfMonth = value);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _TimePickerField(
                      label: 'Start Time',
                      value: _formatTime(_startTime),
                      onTap: () => _pickTime(isStart: true),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _TimePickerField(
                      label: 'End Time',
                      value: _formatTime(_endTime),
                      onTap: () => _pickTime(isStart: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              accountsAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, st) => Text('Failed to load accounts: $e'),
                data: (accounts) {
                  return DropdownButtonFormField<int>(
                    initialValue: _accountId,
                    decoration: const InputDecoration(
                      labelText: 'Pay From Account (optional)',
                    ),
                    items: accounts
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(a.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _accountId = value),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              expenseCategoriesAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, st) => Text('Failed to load categories: $e'),
                data: (categories) {
                  return DropdownButtonFormField<int>(
                    initialValue: _expenseCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Expense Category (optional)',
                    ),
                    items: categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _expenseCategoryId = value),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Alarm Reminder'),
                      subtitle: const Text(
                        'Play a sound from your phone when this payment '
                        'is due',
                      ),
                      value: _alarmEnabled,
                      onChanged: (value) =>
                          setState(() => _alarmEnabled = value),
                    ),
                    if (_alarmEnabled) ...[
                      const Divider(height: 1),
                      const SizedBox(height: AppSpacing.sm),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.music_note_outlined,
                          color: AppColors.primary,
                        ),
                        title: Text(_alarmSoundName ?? 'Default alarm sound'),
                        subtitle: const Text('Tap to choose a different sound'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _pickAlarmSound,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_isEditing)
                SegmentedButton<RecurringPaymentStatus>(
                  segments: const [
                    ButtonSegment(
                      value: RecurringPaymentStatus.unpaid,
                      label: Text('Unpaid'),
                      icon: Icon(Icons.schedule),
                    ),
                    ButtonSegment(
                      value: RecurringPaymentStatus.paid,
                      label: Text('Paid'),
                      icon: Icon(Icons.check_circle_outline),
                    ),
                  ],
                  selected: {_status},
                  onSelectionChanged: (selection) =>
                      setState(() => _status = selection.first),
                ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_isEditing ? 'Save Changes' : 'Add Schedule'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimePickerField extends StatelessWidget {
  const _TimePickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(value),
            const Icon(
              Icons.access_time,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
