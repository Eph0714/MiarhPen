import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';

/// Receipt attachment picker: shows a thumbnail of the current attachment
/// (if any) or a placeholder "Add Receipt" button. Tapping shows a bottom
/// sheet with Camera / Gallery / Remove options.
class AttachmentPicker extends StatelessWidget {
  final String? initialPath;
  final ValueChanged<String?> onChanged;

  const AttachmentPicker({
    super.key,
    this.initialPath,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked == null) return;

    final docsDir = await getApplicationDocumentsDirectory();
    final receiptsDir = Directory(p.join(docsDir.path, 'receipts'));
    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }

    final ext = p.extension(picked.path);
    final fileName = '${const Uuid().v4()}$ext';
    final destPath = p.join(receiptsDir.path, fileName);
    await File(picked.path).copy(destPath);

    onChanged(destPath);
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pick(context, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pick(context, ImageSource.gallery);
                },
              ),
              if (initialPath != null)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: AppColors.expense),
                  title: Text(
                    'Remove Attachment',
                    style: TextStyle(color: AppColors.expense),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onChanged(null);
                  },
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final path = initialPath;
    return InkWell(
      onTap: () => _showOptions(context),
      borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
      child: Container(
        height: 96,
        width: 96,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: path != null && path.isNotEmpty
            ? Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, color: AppColors.primary),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Add Receipt',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }
}
