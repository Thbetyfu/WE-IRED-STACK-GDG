import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// OperationalFeedback provides standardized floating notifications
/// with clear semantic colors, icons, and contrast.
class OperationalFeedback {
  OperationalFeedback._();

  static void showSuccess(BuildContext context, String message) {
    _showSnackBar(
      context: context,
      message: message,
      backgroundColor: AppTheme.statusAman,
      icon: Icons.check_circle_outline,
    );
  }

  static void showError(BuildContext context, String message) {
    _showSnackBar(
      context: context,
      message: message,
      backgroundColor: AppTheme.statusKritis,
      icon: Icons.error_outline,
    );
  }

  static void showWarning(BuildContext context, String message) {
    _showSnackBar(
      context: context,
      message: message,
      backgroundColor: AppTheme.alertWarning,
      icon: Icons.warning_amber_rounded,
    );
  }

  static void showInfo(BuildContext context, String message) {
    _showSnackBar(
      context: context,
      message: message,
      backgroundColor: AppTheme.slate800,
      icon: Icons.info_outline,
    );
  }

  static void _showSnackBar({
    required BuildContext context,
    required String message,
    required Color backgroundColor,
    required IconData icon,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
