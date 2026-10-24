import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// StatusBadge renders an accessible badge indicator for household statuses.
class StatusBadge extends StatelessWidget {
  final String status;
  final String? label;

  const StatusBadge({
    super.key,
    required this.status,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    String displayLabel;

    switch (status.toLowerCase()) {
      case 'aman':
        color = AppTheme.statusAman;
        displayLabel = label ?? 'Aman';
        break;
      case 'titik_kumpul':
        color = AppTheme.statusTitikKumpul;
        displayLabel = label ?? 'Di Titik Kumpul';
        break;
      case 'butuh_bantuan':
        color = AppTheme.statusButuhBantuan;
        displayLabel = label ?? 'Butuh Bantuan';
        break;
      case 'kritis':
        color = AppTheme.statusKritis;
        displayLabel = label ?? 'Kritis';
        break;
      case 'belum_melapor':
      default:
        color = AppTheme.statusBelumMelapor;
        displayLabel = label ?? 'Belum Melapor';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            displayLabel,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// ConnectionStatusPill displays live Cloud / Posko / Offline status.
class ConnectionStatusPill extends StatelessWidget {
  final String mode; // 'cloud', 'posko', 'offline'
  final VoidCallback? onTap;

  const ConnectionStatusPill({
    super.key,
    required this.mode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (mode.toLowerCase()) {
      case 'cloud':
        bg = const Color(0xFFDCFCE7);
        fg = AppTheme.connCloud;
        label = 'Cloud Online';
        icon = Icons.cloud_done;
        break;
      case 'posko':
        bg = const Color(0xFFE0E7FF);
        fg = AppTheme.connPosko;
        label = 'Posko Lokal';
        icon = Icons.router;
        break;
      case 'offline':
      default:
        bg = const Color(0xFFFEE2E2);
        fg = AppTheme.connOffline;
        label = 'Offline';
        icon = Icons.cloud_off;
        break;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: fg.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
