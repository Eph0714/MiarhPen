import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/security/secure_storage_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../../transactions/application/reassign_debit_card_transactions.dart';
import '../../application/backup_service.dart';
import '../../application/export_service.dart';
import '../../application/mysql_sync_service.dart';

/// Data management screen: backup/restore the whole local database, and
/// export/import transactions as CSV/Excel/PDF.
class DataSettingsScreen extends StatefulWidget {
  const DataSettingsScreen({super.key});

  @override
  State<DataSettingsScreen> createState() => _DataSettingsScreenState();
}

class _DataSettingsScreenState extends State<DataSettingsScreen> {
  final _backupService = BackupService();
  final _exportService = ExportService();
  final _mysqlSyncService = MySqlSyncService();
  final _secureStorage = SecureStorageService();

  final _mysqlHostController = TextEditingController();
  final _mysqlPortController = TextEditingController(text: '3306');
  final _mysqlUserController = TextEditingController(text: 'root');
  final _mysqlPasswordController = TextEditingController();
  final _mysqlDatabaseController = TextEditingController(text: 'miarhpen');
  bool _obscureMysqlPassword = true;

  bool _busy = false;
  List<Map<String, String>>? _importPreview;

  @override
  void initState() {
    super.initState();
    _loadMysqlSettings();
  }

  @override
  void dispose() {
    _mysqlHostController.dispose();
    _mysqlPortController.dispose();
    _mysqlUserController.dispose();
    _mysqlPasswordController.dispose();
    _mysqlDatabaseController.dispose();
    super.dispose();
  }

  Future<void> _loadMysqlSettings() async {
    final host = await _secureStorage.read(SecureStorageService.mysqlHost);
    final port = await _secureStorage.read(SecureStorageService.mysqlPort);
    final user = await _secureStorage.read(SecureStorageService.mysqlUser);
    final password = await _secureStorage.read(
      SecureStorageService.mysqlPassword,
    );
    final database = await _secureStorage.read(
      SecureStorageService.mysqlDatabase,
    );
    if (!mounted) return;
    setState(() {
      if (host != null) _mysqlHostController.text = host;
      if (port != null) _mysqlPortController.text = port;
      if (user != null) _mysqlUserController.text = user;
      if (password != null) _mysqlPasswordController.text = password;
      if (database != null) _mysqlDatabaseController.text = database;
    });
  }

  Future<void> _saveMysqlSettings() async {
    await _secureStorage.write(
      SecureStorageService.mysqlHost,
      _mysqlHostController.text.trim(),
    );
    await _secureStorage.write(
      SecureStorageService.mysqlPort,
      _mysqlPortController.text.trim(),
    );
    await _secureStorage.write(
      SecureStorageService.mysqlUser,
      _mysqlUserController.text.trim(),
    );
    await _secureStorage.write(
      SecureStorageService.mysqlPassword,
      _mysqlPasswordController.text,
    );
    await _secureStorage.write(
      SecureStorageService.mysqlDatabase,
      _mysqlDatabaseController.text.trim(),
    );
  }

  Future<void> _syncToMysql() async {
    final host = _mysqlHostController.text.trim();
    if (host.isEmpty) {
      _showError('Enter the MySQL server\'s address first.');
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: 'Sync to MySQL',
      message:
          'This replaces everything currently in the "'
          '${_mysqlDatabaseController.text.trim()}" MySQL database with a '
          'fresh copy of your MiarhPen data. Continue?',
      confirmLabel: 'Sync',
    );
    if (!confirmed) return;

    await _withBusy(() async {
      await _saveMysqlSettings();
      await _mysqlSyncService.sync(
        MySqlSyncConfig(
          host: host,
          port: int.tryParse(_mysqlPortController.text.trim()) ?? 3306,
          user: _mysqlUserController.text.trim(),
          password: _mysqlPasswordController.text,
          database: _mysqlDatabaseController.text.trim(),
        ),
      );
      _showMessage('Synced to MySQL.');
    });
  }

  Future<void> _withBusy(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.expense,
      ),
    );
  }

  Future<void> _createBackup() async {
    await _withBusy(() async {
      final path = await _backupService.createBackup();
      _showMessage('Backup created.');
      if (!mounted) return;
      final share = await showConfirmDialog(
        context,
        title: 'Backup Created',
        message: 'Backup saved. Share it now?',
        confirmLabel: 'Share',
        cancelLabel: 'Not Now',
      );
      if (share) {
        await _backupService.shareBackup(path);
      }
    });
  }

  Future<void> _restoreBackup() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['db'],
    );
    final path = result?.files.single.path;
    if (path == null) return;

    if (!mounted) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Restore Backup',
      message:
          'This replaces all current data with the backup. This cannot be undone. Continue?',
      confirmLabel: 'Restore',
      destructive: true,
    );
    if (!confirmed) return;

    await _withBusy(() async {
      await _backupService.restoreBackup(path);
      _showMessage('Backup restored. Please restart the app.');
    });
  }

  Future<DateTimeRange?> _pickRange() {
    final now = DateTime.now();
    return showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: now,
      ),
    );
  }

  Future<void> _exportCsv() async {
    final range = await _pickRange();
    if (range == null) return;
    await _withBusy(() async {
      final path = await _exportService.exportTransactionsCsv(
        from: range.start,
        to: range.end,
      );
      _showMessage('CSV exported.');
      if (!mounted) return;
      final share = await showConfirmDialog(
        context,
        title: 'Export Complete',
        message: 'CSV file saved. Share it now?',
        confirmLabel: 'Share',
        cancelLabel: 'Not Now',
      );
      if (share) await _backupService.shareBackup(path);
    });
  }

  Future<void> _exportExcel() async {
    final range = await _pickRange();
    if (range == null) return;
    await _withBusy(() async {
      final path = await _exportService.exportTransactionsExcel(
        from: range.start,
        to: range.end,
      );
      _showMessage('Excel file exported.');
      if (!mounted) return;
      final share = await showConfirmDialog(
        context,
        title: 'Export Complete',
        message: 'Excel file saved. Share it now?',
        confirmLabel: 'Share',
        cancelLabel: 'Not Now',
      );
      if (share) await _backupService.shareBackup(path);
    });
  }

  Future<void> _reassignDebitCardTransactions() async {
    await _withBusy(() async {
      final moved = await reassignDebitCardTransactionsIfNeeded();
      _showMessage(
        moved == 0
            ? 'Nothing to fix — no transactions were posted to a debit '
                  'card account.'
            : 'Fixed $moved transaction${moved == 1 ? '' : 's'} — moved '
                  'from a debit card onto its linked bank account. Cash '
                  'in Bank should now be correct.',
      );
    });
  }

  Future<void> _pickAndImportCsv() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    final path = result?.files.single.path;
    if (path == null) return;

    await _withBusy(() async {
      final rows = await _exportService.importTransactionsCsv(path);
      setState(() => _importPreview = rows);
      _showMessage('${rows.length} row(s) parsed. Review below.');
    });
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      visible: _busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Data Management')),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _SectionHeader('Backup'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create a full backup of your data and share it wherever you like.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton.icon(
                    onPressed: _busy ? null : _createBackup,
                    icon: const Icon(Icons.backup_outlined),
                    label: const Text('Create Backup'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SectionHeader('Restore'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Restore your data from a previously created backup file.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _restoreBackup,
                    icon: const Icon(Icons.restore_outlined),
                    label: const Text('Pick Backup File'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SectionHeader('Export'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Export your transactions and transfers for a date range.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _exportCsv,
                        icon: const Icon(Icons.description_outlined),
                        label: const Text('Export CSV'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _exportExcel,
                        icon: const Icon(Icons.table_chart_outlined),
                        label: const Text('Export Excel'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SectionHeader('Import'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Import transactions from a CSV file matching the exported format.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pickAndImportCsv,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Pick CSV File'),
                  ),
                  if (_importPreview != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '${_importPreview!.length} row(s) parsed (preview only — not yet imported):',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // TODO: wire through TransactionRepository once reviewed
                    // — this preview only parses the file, it never writes
                    // to the database.
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _importPreview!.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final row = _importPreview![index];
                          final summary = row.entries
                              .map((e) => '${e.key}: ${e.value}')
                              .join('  |  ');
                          return Text(
                            summary,
                            style: Theme.of(context).textTheme.bodySmall,
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SectionHeader('Data Repair'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Moves any transaction still posted to a debit card '
                    'account onto the bank account it\'s linked to. A '
                    'debit card holds no balance of its own, so leaving a '
                    'transaction posted directly to one left it out of '
                    'Cash in Bank / Total Available Funds even though it '
                    'saved correctly. Only the account reference changes — '
                    'amount, date, description, and category are '
                    'untouched. Safe to run more than once.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _reassignDebitCardTransactions,
                    icon: const Icon(Icons.build_outlined),
                    label: const Text('Fix Debit Card Transactions'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SectionHeader('Sync to MySQL (Desktop)'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Push a snapshot of your data to a MySQL database on a '
                    'computer for viewing in MySQL Workbench, phpMyAdmin, '
                    'etc. This is one-way and for desktop viewing only — '
                    'MiarhPen itself always keeps working fully offline '
                    'using its own local database on this device. Your '
                    'phone and the MySQL server must be reachable from each '
                    'other (usually the same Wi-Fi network) — "localhost" '
                    'here means the computer running MySQL, not this phone.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _mysqlHostController,
                    decoration: const InputDecoration(
                      labelText: 'Server Address',
                      hintText: 'e.g. 192.168.1.10',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _mysqlPortController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Port'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _mysqlUserController,
                    decoration: const InputDecoration(labelText: 'Username'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _mysqlPasswordController,
                    obscureText: _obscureMysqlPassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureMysqlPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscureMysqlPassword = !_obscureMysqlPassword,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _mysqlDatabaseController,
                    decoration: const InputDecoration(labelText: 'Database'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton.icon(
                    onPressed: _busy ? null : _syncToMysql,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Sync to MySQL'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
