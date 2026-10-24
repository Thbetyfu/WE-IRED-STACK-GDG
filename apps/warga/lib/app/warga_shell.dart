import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui/ui.dart';

import 'warga_state.dart';

/// Mobile-first ergonomic navigation shell for Aplikasi Warga.
///
/// Provides:
/// - Persistent, accessible bottom navigation bar with large touch targets (>= 56dp)
/// - Clean route switching for the 4 primary operational tabs:
///   1. Beranda (/)
///   2. Pengumuman (/announcements)
///   3. Kesiapsiagaan (/education)
///   4. Rumah Saya (/household)
/// - Live offline/online network status indicator banner
class WargaShell extends ConsumerWidget {
  final Widget child;
  final String currentPath;

  const WargaShell({
    super.key,
    required this.child,
    required this.currentPath,
  });

  int _calculateSelectedIndex() {
    if (currentPath == '/') return 0;
    if (currentPath.startsWith('/announcements')) return 1;
    if (currentPath.startsWith('/education')) return 2;
    if (currentPath.startsWith('/household')) return 3;
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/announcements');
        break;
      case 2:
        context.go('/education');
        break;
      case 3:
        context.go('/household');
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wargaProvider);
    final selectedIndex = _calculateSelectedIndex();
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = width >= 640;

    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      body: Row(
        children: [
          // If on tablet or wider screen, show accessible navigation rail
          if (isTablet)
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (idx) => _onItemTapped(context, idx),
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
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shield, color: AppTheme.primaryBlue, size: 24),
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: Text('Beranda'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.campaign_outlined),
                  selectedIcon: Icon(Icons.campaign),
                  label: Text('Pengumuman'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.school_outlined),
                  selectedIcon: Icon(Icons.school),
                  label: Text('Siaga'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.family_restroom_outlined),
                  selectedIcon: Icon(Icons.family_restroom),
                  label: Text('Rumah'),
                ),
              ],
            ),

          // Main page body
          Expanded(
            child: Column(
              children: [
                // Top micro-strip for offline/relay status indicator if pending
                if (state.syncStatus != 'synced')
                  Container(
                    width: double.infinity,
                    color: state.syncStatus == 'relay'
                        ? const Color(0xFFF3E8FF)
                        : const Color(0xFFFEF3C7),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          state.syncStatus == 'relay' ? Icons.bluetooth : Icons.cloud_off,
                          size: 14,
                          color: state.syncStatus == 'relay'
                              ? const Color(0xFF7E22CE)
                              : const Color(0xFFB45309),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          state.syncStatus == 'relay'
                              ? 'Jaringan Offline: Laporan diteruskan melalui Relay Bluetooth warga sekitar'
                              : 'Koneksi Offline: Laporan tersimpan di ponsel dan dikirim otomatis saat sinyal pulih',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: state.syncStatus == 'relay'
                                ? const Color(0xFF7E22CE)
                                : const Color(0xFFB45309),
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

      // Ergonomic mobile Bottom Navigation Bar with large touch targets
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
                  onDestinationSelected: (idx) => _onItemTapped(context, idx),
                  indicatorColor: AppTheme.primaryBlue.withValues(alpha: 0.12),
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined, size: 24),
                      selectedIcon: Icon(Icons.home, color: AppTheme.primaryBlue, size: 24),
                      label: 'Beranda',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.campaign_outlined, size: 24),
                      selectedIcon: Icon(Icons.campaign, color: AppTheme.primaryBlue, size: 24),
                      label: 'Pengumuman',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.shield_outlined, size: 24),
                      selectedIcon: Icon(Icons.shield, color: AppTheme.primaryBlue, size: 24),
                      label: 'Siaga & Tas',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.family_restroom_outlined, size: 24),
                      selectedIcon: Icon(Icons.family_restroom, color: AppTheme.primaryBlue, size: 24),
                      label: 'Rumah Saya',
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
