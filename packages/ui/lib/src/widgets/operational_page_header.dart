import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// OperationalPageHeader provides a standardized, responsive enterprise title bar
/// for command center dashboard and administration pages.
///
/// Automatically shifts actions underneath the title on tablet / compact viewports
/// using [LayoutBuilder], preventing RenderFlex overflows.
class OperationalPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? statusBadge;
  final List<Widget> actions;
  final Widget? leading;
  final double breakpoint;

  const OperationalPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.statusBadge,
    this.actions = const [],
    this.leading,
    this.breakpoint = 920,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < breakpoint;

        final titleRow = Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: [
            if (leading != null) leading!,
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.slate900,
                letterSpacing: -0.3,
              ),
            ),
            if (statusBadge != null) statusBadge!,
          ],
        );

        final titleSection = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            titleRow,
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.slate500,
                  height: 1.4,
                ),
              ),
            ],
          ],
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              titleSection,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: actions,
                ),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleSection),
            if (actions.isNotEmpty) ...[
              const SizedBox(width: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: actions,
              ),
            ],
          ],
        );
      },
    );
  }
}
