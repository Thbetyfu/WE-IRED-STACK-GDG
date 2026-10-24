import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// EmergencyActionButton satisfies NFR-USA-02:
/// - Minimum height: >= 64 dp
/// - Text size: >= 20 sp
/// - Meets WCAG 2.1 AA/AAA contrast
/// - Color-blind friendly icon + descriptive text
class EmergencyActionButton extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final VoidCallback? onPressed;
  final bool isLoading;

  const EmergencyActionButton({
    super.key,
    required this.label,
    this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.onPressed,
    this.isLoading = false,
  });

  /// Factory for "Aman di Rumah" (Green)
  factory EmergencyActionButton.aman({
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return EmergencyActionButton(
      label: 'Aman di Rumah',
      subtitle: 'Kondisi keluarga aman & terkendali',
      icon: Icons.check_circle,
      backgroundColor: AppTheme.statusAman,
      foregroundColor: Colors.white,
      borderColor: const Color(0xFF15803D),
      onPressed: onPressed,
      isLoading: isLoading,
    );
  }

  /// Factory for "Sudah di Titik Kumpul" (Blue)
  factory EmergencyActionButton.titikKumpul({
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return EmergencyActionButton(
      label: 'Di Titik Kumpul',
      subtitle: 'Sudah berada di lokasi evakuasi',
      icon: Icons.flag,
      backgroundColor: AppTheme.statusTitikKumpul,
      foregroundColor: Colors.white,
      borderColor: const Color(0xFF1D4ED8),
      onPressed: onPressed,
      isLoading: isLoading,
    );
  }

  /// Factory for "Butuh Bantuan" (High Contrast Red / Orange)
  factory EmergencyActionButton.butuhBantuan({
    required VoidCallback? onPressed,
    bool isLoading = false,
    bool isKritis = false,
  }) {
    return EmergencyActionButton(
      label: 'Butuh Bantuan',
      subtitle: isKritis
          ? 'KONDISI KRITIS / DARURAT MEDIS'
          : 'Evakuasi, logistik, atau medis',
      icon: isKritis ? Icons.warning_rounded : Icons.sos,
      backgroundColor: isKritis ? AppTheme.statusKritis : AppTheme.statusButuhBantuan,
      foregroundColor: Colors.white,
      borderColor: isKritis ? const Color(0xFFB91C1C) : const Color(0xFFC2410C),
      onPressed: onPressed,
      isLoading: isLoading,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          height: subtitle != null ? 84 : 68,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: backgroundColor.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: foregroundColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: foregroundColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: foregroundColor.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (isLoading)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                  ),
                )
              else
                Icon(Icons.arrow_forward_ios, color: foregroundColor.withValues(alpha: 0.7), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
