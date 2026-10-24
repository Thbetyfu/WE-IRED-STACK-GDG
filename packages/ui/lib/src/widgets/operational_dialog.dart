import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// OperationalConfirmDialog provides a unified, accessible modal dialog
/// for critical operations (e.g. status override, data sync, report rejection, evacuation confirmation).
class OperationalConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final IconData icon;
  final Color? iconColor;
  final bool isDestructive;

  const OperationalConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Konfirmasi',
    this.cancelLabel = 'Batal',
    required this.onConfirm,
    this.onCancel,
    this.icon = Icons.info_outline,
    this.iconColor,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = iconColor ?? (isDestructive ? AppTheme.statusKritis : AppTheme.primaryBlue);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: effectiveColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: effectiveColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.slate900,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: const TextStyle(
          fontSize: 13,
          color: AppTheme.slate600,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: onCancel ?? () => Navigator.of(context).pop(false),
          child: Text(
            cancelLabel,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.slate600),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDestructive ? AppTheme.statusKritis : AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
          ),
          onPressed: () {
            Navigator.of(context).pop(true);
            onConfirm();
          },
          child: Text(
            confirmLabel,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

/// Helper function to display the standard operational confirmation dialog.
Future<bool?> showOperationalConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Konfirmasi',
  String cancelLabel = 'Batal',
  required VoidCallback onConfirm,
  IconData icon = Icons.info_outline,
  Color? iconColor,
  bool isDestructive = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => OperationalConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      onConfirm: onConfirm,
      icon: icon,
      iconColor: iconColor,
      isDestructive: isDestructive,
    ),
  );
}
