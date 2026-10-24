import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// LoadingStateView renders a clean, accessible loading indicator with contextual label.
class LoadingStateView extends StatelessWidget {
  final String message;

  const LoadingStateView({
    super.key,
    this.message = 'Memuat data...',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.slate600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// EmptyStateView renders a helpful zero-data view with optional action button.
class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateView({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.slate100,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.slate200),
              ),
              child: Icon(icon, size: 36, color: AppTheme.slate500),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.slate800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.slate500,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(actionLabel!),
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ErrorStateView renders actionable error messages with a retry option.
class ErrorStateView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorStateView({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.statusKritisBg,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.statusKritisBorder),
              ),
              child: const Icon(Icons.error_outline, size: 32, color: AppTheme.statusKritis),
            ),
            const SizedBox(height: 14),
            const Text(
              'Terjadi Kendala Teknis',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.slate800,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.slate600,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Coba Lagi'),
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// OfflineSyncBanner indicates local outbox state and network status.
class OfflineSyncBanner extends StatelessWidget {
  final int pendingCount;
  final VoidCallback? onManualSync;

  const OfflineSyncBanner({
    super.key,
    required this.pendingCount,
    this.onManualSync,
  });

  @override
  Widget build(BuildContext context) {
    if (pendingCount <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFFDE68A)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 16, color: Color(0xFFD97706)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$pendingCount laporan tersimpan lokal di outbox (akan dikirim saat terhubung atau via relawan)',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF92400E),
              ),
            ),
          ),
          if (onManualSync != null)
            TextButton(
              onPressed: onManualSync,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: const Color(0xFF92400E),
              ),
              child: const Text('Sinkronkan Sekarang', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

/// DemoDataBadge clearly indicates when displayed data is synthetic / simulation.
class DemoDataBadge extends StatelessWidget {
  final String note;

  const DemoDataBadge({
    super.key,
    this.note = 'DATA SIMULASI / BENCHMARK',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.science_outlined, size: 11, color: Color(0xFF4B5563)),
          const SizedBox(width: 4),
          Text(
            note,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4B5563),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
