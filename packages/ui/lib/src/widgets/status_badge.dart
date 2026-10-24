import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// StatusBadge renders an accessible badge indicator for household statuses.
/// Complies with NFR-USA-03: distinguishes status using color, icon, and text.
class StatusBadge extends StatelessWidget {
  final String status;
  final String? label;
  final bool compact;

  const StatusBadge({
    super.key,
    required this.status,
    this.label,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    Color fg;
    Color bg;
    Color border;
    String displayLabel;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'aman':
        fg = AppTheme.statusAman;
        bg = AppTheme.statusAmanBg;
        border = AppTheme.statusAmanBorder;
        displayLabel = label ?? 'Aman';
        icon = Icons.check_circle_outline;
        break;
      case 'titik_kumpul':
        fg = AppTheme.statusTitikKumpul;
        bg = AppTheme.statusTitikKumpulBg;
        border = AppTheme.statusTitikKumpulBorder;
        displayLabel = label ?? 'Di Titik Kumpul';
        icon = Icons.flag_outlined;
        break;
      case 'butuh_bantuan':
        fg = AppTheme.statusButuhBantuan;
        bg = AppTheme.statusButuhBantuanBg;
        border = AppTheme.statusButuhBantuanBorder;
        displayLabel = label ?? 'Butuh Bantuan';
        icon = Icons.help_outline;
        break;
      case 'kritis':
        fg = AppTheme.statusKritis;
        bg = AppTheme.statusKritisBg;
        border = AppTheme.statusKritisBorder;
        displayLabel = label ?? 'Kritis';
        icon = Icons.warning_amber_rounded;
        break;
      case 'belum_melapor':
      default:
        fg = AppTheme.statusBelumMelapor;
        bg = AppTheme.statusBelumMelaporBg;
        border = AppTheme.statusBelumMelaporBorder;
        displayLabel = label ?? 'Belum Melapor';
        icon = Icons.schedule_outlined;
        break;
    }

    final content = compact
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppTheme.radiusXs),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 12, color: fg),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    displayLabel,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    displayLabel,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );

    return Semantics(
      label: 'Status Keselamatan: $displayLabel',
      container: true,
      child: content,
    );
  }
}

/// PriorityTierBadge renders priority tiers (Kritis, Mendesak, Reguler)
/// based on SDD 6.1 formula for tasks and triage.
class PriorityTierBadge extends StatelessWidget {
  final String tier; // 'kritis', 'mendesak', 'reguler'
  final double? score;

  const PriorityTierBadge({
    super.key,
    required this.tier,
    this.score,
  });

  @override
  Widget build(BuildContext context) {
    Color fg;
    Color bg;
    Color border;
    String label;

    switch (tier.toLowerCase()) {
      case 'kritis':
        fg = AppTheme.statusKritis;
        bg = AppTheme.statusKritisBg;
        border = AppTheme.statusKritisBorder;
        label = 'KRITIS';
        break;
      case 'mendesak':
        fg = AppTheme.alertWarning;
        bg = AppTheme.drillBg;
        border = AppTheme.drillBorder;
        label = 'MENDESAK';
        break;
      case 'reguler':
      default:
        fg = AppTheme.statusTitikKumpul;
        bg = AppTheme.statusTitikKumpulBg;
        border = AppTheme.statusTitikKumpulBorder;
        label = 'REGULER';
        break;
    }

    final displayText = score != null ? '$label (${score!.toStringAsFixed(1)})' : label;

    return Semantics(
      label: 'Prioritas: $displayText',
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppTheme.radiusXs),
          border: Border.all(color: border),
        ),
        child: Text(
          displayText,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w800,
            fontSize: 10,
            letterSpacing: 0.4,
          ),
        ),
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
    Color border;
    String label;
    IconData icon;

    switch (mode.toLowerCase()) {
      case 'cloud':
        bg = const Color(0xFFDCFCE7);
        fg = AppTheme.connCloud;
        border = const Color(0xFF86EFAC);
        label = 'Cloud Online';
        icon = Icons.cloud_done;
        break;
      case 'posko':
        bg = const Color(0xFFEEF2FF);
        fg = AppTheme.connPosko;
        border = const Color(0xFFC7D2FE);
        label = 'Posko Lokal';
        icon = Icons.router;
        break;
      case 'offline':
      default:
        bg = const Color(0xFFFEE2E2);
        fg = AppTheme.connOffline;
        border = const Color(0xFFFECACA);
        label = 'Offline (Lokal)';
        icon = Icons.cloud_off;
        break;
    }

    final pillWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: border),
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
    );

    if (onTap == null) {
      return Semantics(
        label: 'Status Koneksi: $label',
        child: pillWidget,
      );
    }

    return Semantics(
      button: true,
      label: 'Ubah Mode Koneksi: $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: pillWidget,
      ),
    );
  }
}

/// SyncStatusBadge renders the outbox/sync state of reports per FR-RPT-09.
class SyncStatusBadge extends StatelessWidget {
  final String status; // 'synced', 'pending', 'relay', 'failed'

  const SyncStatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    Color fg;
    Color bg;
    Color border;
    String label;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'synced':
      case 'terkirim':
        fg = AppTheme.statusAman;
        bg = AppTheme.statusAmanBg;
        border = AppTheme.statusAmanBorder;
        label = 'Terkirim ke Server';
        icon = Icons.cloud_done_outlined;
        break;
      case 'relay':
      case 'diteruskan':
        fg = const Color(0xFF4F46E5);
        bg = const Color(0xFFEEF2FF);
        border = const Color(0xFFC7D2FE);
        label = 'Diteruskan via Mesh Relay';
        icon = Icons.bluetooth_searching_outlined;
        break;
      case 'failed':
      case 'gagal':
        fg = AppTheme.statusKritis;
        bg = AppTheme.statusKritisBg;
        border = AppTheme.statusKritisBorder;
        label = 'Gagal Kirim';
        icon = Icons.error_outline;
        break;
      case 'pending':
      case 'outbox':
      default:
        fg = const Color(0xFFD97706);
        bg = const Color(0xFFFEF3C7);
        border = const Color(0xFFFDE68A);
        label = 'Menunggu Sinyal (Outbox)';
        icon = Icons.schedule_outlined;
        break;
    }

    return Semantics(
      label: 'Status Sinkronisasi: $label',
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: border),
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
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
