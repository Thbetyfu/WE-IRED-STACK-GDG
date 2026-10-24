import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// OperationalMetricTile renders structured KPI numbers with high contrast and clarity.
class OperationalMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? accentColor;
  final VoidCallback? onTap;

  const OperationalMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.icon,
    this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = accentColor ?? AppTheme.slate700;

    final content = Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: effectiveColor),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.slate500,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: effectiveColor,
              letterSpacing: -0.5,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.slate500,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return content;

    return Semantics(
      button: true,
      label: '$label: $value',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: content,
      ),
    );
  }
}

/// OperationalSectionHeader provides a consistent title bar for screen sections.
class OperationalSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const OperationalSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.slate900,
                    letterSpacing: -0.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.slate500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// OperationalCard provides a structured, accessible container
/// used across Dashboard panels, Warga households, and Relawan task views.
class OperationalCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final Color borderColor;
  final double radius;
  final VoidCallback? onTap;

  const OperationalCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.spacingMd),
    this.backgroundColor = Colors.white,
    this.borderColor = AppTheme.borderSubtle,
    this.radius = AppTheme.radiusMd,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor),
      boxShadow: AppTheme.shadowSubtle,
    );

    if (onTap == null) {
      return Container(
        padding: padding,
        decoration: decoration,
        child: child,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          padding: padding,
          decoration: decoration,
          child: child,
        ),
      ),
    );
  }
}

/// OperationalChoiceChip is an accessible, touch-friendly choice widget (>= 48dp)
/// for forms, filter bars, and status pickers.
class OperationalChoiceChip extends StatelessWidget {
  final String label;
  final String? sublabel;
  final IconData? icon;
  final bool isSelected;
  final Color? activeColor;
  final VoidCallback onTap;

  const OperationalChoiceChip({
    super.key,
    required this.label,
    this.sublabel,
    this.icon,
    required this.isSelected,
    this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? AppTheme.primaryBlue;

    return Semantics(
      selected: isSelected,
      button: true,
      label: sublabel != null ? '$label ($sublabel)' : label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppTheme.touchTargetMin),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: isSelected ? color : AppTheme.borderSubtle,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: isSelected ? color : AppTheme.slate500),
                const SizedBox(height: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color : AppTheme.slate800,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (sublabel != null) ...[
                const SizedBox(height: 2),
                Text(
                  sublabel!,
                  style: TextStyle(
                    fontSize: 9,
                    color: isSelected ? color : AppTheme.slate500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
