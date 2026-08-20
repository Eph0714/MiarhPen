import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/db/app_database.dart';

/// Handles copying the live sqflite database file out to a timestamped
/// backup, sharing a backup file via the OS share sheet, and restoring a
/// previously-created (or user-picked) backup file back over the live DB.
class BackupService {
  /// Copies the live DB file into `<documents>/backups/` as a timestamped
  /// file, e.g. `miarhpen_backup_2026-08-18_193000.db`. Returns the new
  /// file's absolute path.
  Future<String> createBackup() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(documentsDir.path, AppConstants.dbFileName);
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      throw Exception('No database file found to back up.');
    }

    final backupsDir = Directory(p.join(documentsDir.path, 'backups'));
    if (!await backupsDir.exists()) {
      await backupsDir.create(recursive: true);
    }

    final timestamp = DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now());
    final backupPath = p.join(backupsDir.path, 'miarhpen_backup_$timestamp.db');

    await dbFile.copy(backupPath);
    return backupPath;
  }

  /// Shares a backup file (or any file) via the platform share sheet.
  Future<void> shareBackup(String path) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], text: 'MiarhPen backup'),
    );
  }

  /// Validates [backupFilePath] is a real, openable SQLite database, then
  /// closes the live DB and overwrites it with the backup's bytes.
  ///
  /// Throws an [Exception] with a user-facing message on any validation
  /// failure — the live DB is never touched unless validation succeeds.
  Future<void> restoreBackup(String backupFilePath) async {
    final backupFile = File(backupFilePath);
    if (!await backupFile.exists()) {
      throw Exception('Backup file not found.');
    }

    Database? testDb;
    try {
      testDb = await openDatabase(backupFilePath, readOnly: true);
      await testDb.rawQuery('SELECT count(*) FROM sqlite_master');
    } catch (_) {
      throw Exception('This file does not look like a valid MiarhPen backup.');
    } finally {
      await testDb?.close();
    }

    await AppDatabase.instance.close();

    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(documentsDir.path, AppConstants.dbFileName);
    await backupFile.copy(dbPath);
    // Next AppDatabase.instance.database call reopens the restored file.
  }
}
