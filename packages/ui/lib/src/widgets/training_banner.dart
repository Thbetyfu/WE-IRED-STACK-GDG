import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// TrainingBanner displays the clear mode status across all apps (F-05).
/// Guarantees that users never confuse a drill/exercise with real emergency.
class TrainingBanner extends StatelessWidget {
  final bool isDrill;
  final String? customMessage;
  final VoidCallback? onDismiss;

  const TrainingBanner({
    super.key,
    required this.isDrill,
    this.customMessage,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (isDrill) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.drillBg,
          border: const Border(
            top: BorderSide(color: AppTheme.drillBorder, width: 1.5),
            bottom: BorderSide(color: AppTheme.drillBorder, width: 1.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.drillAmber,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.sports_score, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '[LATIHAN EVAKUASI / DRILL SIMULASI]',
                    style: TextStyle(
                      color: AppTheme.drillAmberDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    customMessage ?? 'Seluruh data laporan pada mode ini dicatat terpisah dan tidak memicu darurat riil.',
                    style: const TextStyle(
                      color: Color(0xFF78350F),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (onDismiss != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: AppTheme.drillAmberDark),
                onPressed: onDismiss,
              ),
          ],
        ),
      );
    }

    // Active Real Incident Alert Banner
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.statusKritisBg,
        border: const Border(
          top: BorderSide(color: AppTheme.statusKritisBorder, width: 1.5),
          bottom: BorderSide(color: AppTheme.statusKritisBorder, width: 1.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.statusKritis,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'SIAGA DARURAT AKTIF (NYATA)',
                  style: TextStyle(
                    color: Color(0xFF991B1B),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  customMessage ?? 'Laporkan segera status keselamatan rumah tangga Anda melalui tombol di bawah.',
                  style: const TextStyle(
                    color: Color(0xFF7F1D1D),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
