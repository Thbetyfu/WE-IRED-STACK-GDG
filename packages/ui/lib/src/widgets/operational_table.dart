import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// OperationalTableContainer wraps data tables with responsive horizontal scrolling,
/// standard border radius, clean headers, and visual cues.
class OperationalTableContainer extends StatelessWidget {
  final Widget child;
  final String? headerTitle;
  final Widget? trailing;

  const OperationalTableContainer({
    super.key,
    required this.child,
    this.headerTitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: AppTheme.shadowSubtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (headerTitle != null || trailing != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
                color: AppTheme.slate50,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (headerTitle != null)
                    Text(
                      headerTitle!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.slate900,
                      ),
                    ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          Scrollbar(
            thumbVisibility: false,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
