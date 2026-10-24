import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui/ui.dart';

import 'relawan_state.dart';

/// Ergonomic, outdoor-readable navigation shell for Aplikasi Relawan WE-IRED.
///
/// Features:
/// - Responsive layout: NavigationRail on tablet (>= 640dp) and Bottom Navigation Bar on mobile (< 640dp)
/// - Large touch targets (>= 56dp) for outdoor gloved / one-handed field operation
/// - Status banner indicating Offline Outbox queue or BLE data mule packet buffer
/// - Visual badges for pending tasks and collected packets
class RelawanShell extends ConsumerWidget {
  final Widget child;
  final String? currentPath;

  const RelawanShell({
    super.key,
    required this.child,
    this.currentPath,
  });

  int _calculateSelectedIndex(BuildContext context) {
    if (currentPath != null) {
      if (currentPath!.startsWith('/block_map')) return 1;
      if (currentPath!.startsWith('/proxy_report')) return 2;
      if (currentPath!.startsWith('/collector')) return 3;
      if (currentPath!.startsWith('/posko') ||
          currentPath!.startsWith('/topology') ||
          currentPath!.startsWith('/beacon_tools') ||
          currentPath!.startsWith('/first_aid')) {
        return 4;
      }
      return 0; // /tasks
    }

    try {
      final location = GoRouterState.of(context).uri.toString();
      if (location.startsWith('/block_map')) return 1;
      if (location.startsWith('/proxy_report')) return 2;
      if (location.startsWith('/collector')) return 3;
      if (location.startsWith('/posko') ||
          location.startsWith('/topology') ||
          location.startsWith('/beacon_tools') ||
          location.startsWith('/first_aid')) {
        return 4;
      }
    } catch (_) {
      return 0;
    }
    return 0; // /tasks
  }

  void _onItemTapped(int index, BuildContext context) {
    try {
      switch (index) {
        case 0:
          context.go('/tasks');
          break;
        case 1:
          context.go('/block_map');
          break;
        case 2:
          context.go('/proxy_report');
          break;
        case 3:
          context.go('/collector');
          break;
        case 4:
          context.go('/posko');
          break;
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(relawanProvider);
    final selectedIndex = _calculateSelectedIndex(context);
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = width >= 640;

    // Badges calculation
    final overdueCount = state.tasks.where((t) => t.isOverdue).length;
    final activeCount = state.tasks.where((t) => t.status != 'selesai').length;

    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      body: Row(
        children: [
          // Tablet Navigation Rail
          if (isTablet)
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (idx) => _onItemTapped(idx, context),
              labelType: NavigationRailLabelType.all,
              backgroundColor: Colors.white,
              selectedIconTheme: const IconThemeData(color: AppTheme.primaryBlue, size: 26),
              unselectedIconTheme: const IconThemeData(color: AppTheme.slate500, size: 24),
              selectedLabelTextStyle: const TextStyle(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              unselectedLabelTextStyle: const TextStyle(
                color: AppTheme.slate600,
                fontSize: 11,
              ),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.volunteer_activism, color: AppTheme.primaryBlue, size: 24),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.slate100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: Text(
                        state.assignedBlock,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.slate800),
                      ),
                    ),
                  ],
                ),
              ),
              destinations: [
                NavigationRailDestination(
                  icon: Badge(
                    isLabelVisible: overdueCount > 0 || activeCount > 0,
                    label: Text('${overdueCount > 0 ? overdueCount : activeCount}'),
                    backgroundColor: overdueCount > 0 ? AppTheme.statusKritis : AppTheme.primaryBlue,
                    child: const Icon(Icons.assignment_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: overdueCount > 0 || activeCount > 0,
                    label: Text('${overdueCount > 0 ? overdueCount : activeCount}'),
                    backgroundColor: overdueCount > 0 ? AppTheme.statusKritis : AppTheme.primaryBlue,
                    child: const Icon(Icons.assignment),
                  ),
                  label: const Text('Tugas'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.map_outlined),
                  selectedIcon: Icon(Icons.map),
                  label: Text('Peta Blok'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.person_add_alt_1_outlined),
                  selectedIcon: Icon(Icons.person_add_alt_1),
                  label: Text('Lapor Proksi'),
                ),
                NavigationRailDestination(
                  icon: Badge(
                    isLabelVisible: state.collectedPacketsCount > 0,
                    label: Text('${state.collectedPacketsCount}'),
                    backgroundColor: AppTheme.statusTitikKumpul,
                    child: const Icon(Icons.bluetooth_searching),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: state.collectedPacketsCount > 0,
                    label: Text('${state.collectedPacketsCount}'),
                    backgroundColor: AppTheme.statusTitikKumpul,
                    child: const Icon(Icons.bluetooth_connected),
                  ),
                  label: const Text('Kolektor'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.hub_outlined),
                  selectedIcon: Icon(Icons.hub),
                  label: Text('Posko & Alat'),
                ),
              ],
            ),

          // Main Screen Content Area
          Expanded(
            child: Column(
              children: [
                // Top Operational micro-strip for Connectivity / Outbox / Packet status
                if (!state.isPoskoConnected || state.pendingOutboxCount > 0)
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFFEF3C7),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off, size: 14, color: Color(0xFFB45309)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            !state.isPoskoConnected
                                ? 'Mode Luring: Tersimpan di Outbox ponsel (${state.pendingOutboxCount} perubahan pending). Otomatis kirim saat terhubung ke Wi-Fi Posko.'
                                : '${state.pendingOutboxCount} perubahan status menunggu pengiriman ke Posko Lokal.',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF92400E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (state.isCollectorScanning && state.collectedPacketsCount > 0)
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFEFF6FF),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bluetooth_audio, size: 14, color: AppTheme.primaryBlue),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Kolektor BLE Aktif: ${state.collectedPacketsCount} paket laporan warga tersimpan di buffer HP untuk diserahkan ke Posko.',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryBlue,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),

      // Ergonomic Mobile Bottom Navigation Bar with large touch targets
      bottomNavigationBar: isTablet
          ? null
          : Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: AppTheme.borderSubtle, width: 1),
                ),
              ),
              child: SafeArea(
                child: NavigationBar(
                  height: 64,
                  elevation: 0,
                  backgroundColor: Colors.white,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (idx) => _onItemTapped(idx, context),
                  indicatorColor: AppTheme.primaryBlue.withValues(alpha: 0.12),
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  destinations: [
                    NavigationDestination(
                      icon: Badge(
                        isLabelVisible: overdueCount > 0 || activeCount > 0,
                        label: Text('${overdueCount > 0 ? overdueCount : activeCount}'),
                        backgroundColor: overdueCount > 0 ? AppTheme.statusKritis : AppTheme.primaryBlue,
                        child: const Icon(Icons.assignment_outlined, size: 22),
                      ),
                      selectedIcon: Badge(
                        isLabelVisible: overdueCount > 0 || activeCount > 0,
                        label: Text('${overdueCount > 0 ? overdueCount : activeCount}'),
                        backgroundColor: overdueCount > 0 ? AppTheme.statusKritis : AppTheme.primaryBlue,
                        child: const Icon(Icons.assignment, size: 22, color: AppTheme.primaryBlue),
                      ),
                      label: 'Tugas',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.map_outlined, size: 22),
                      selectedIcon: Icon(Icons.map, size: 22, color: AppTheme.primaryBlue),
                      label: 'Peta Blok',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.person_add_alt_1_outlined, size: 22),
                      selectedIcon: Icon(Icons.person_add_alt_1, size: 22, color: AppTheme.primaryBlue),
                      label: 'Proksi',
                    ),
                    NavigationDestination(
                      icon: Badge(
                        isLabelVisible: state.collectedPacketsCount > 0,
                        label: Text('${state.collectedPacketsCount}'),
                        backgroundColor: AppTheme.statusTitikKumpul,
                        child: const Icon(Icons.bluetooth_searching, size: 22),
                      ),
                      selectedIcon: Badge(
                        isLabelVisible: state.collectedPacketsCount > 0,
                        label: Text('${state.collectedPacketsCount}'),
                        backgroundColor: AppTheme.statusTitikKumpul,
                        child: const Icon(Icons.bluetooth_connected, size: 22, color: AppTheme.primaryBlue),
                      ),
                      label: 'Kolektor',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.hub_outlined, size: 22),
                      selectedIcon: Icon(Icons.hub, size: 22, color: AppTheme.primaryBlue),
                      label: 'Posko',
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
