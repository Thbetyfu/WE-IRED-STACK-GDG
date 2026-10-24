import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui/ui.dart';

import 'auth_provider.dart';

class DashboardShell extends ConsumerWidget {
  final Widget child;

  const DashboardShell({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final currentPath = GoRouterState.of(context).uri.toString();

    final isOperator = authState.role == 'operator';
    final isAdminWilayah = authState.role == 'admin_wilayah' || isOperator;

    return Scaffold(
      body: Row(
        children: [
          // Left Sidebar Navigation
          Container(
            width: 250,
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A), // Dark slate
              border: Border(right: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: Column(
              children: [
                // Brand Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.shield, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WE-IRED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'Dashboard Posko & RT',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF1E293B), height: 1),

                // Navigation Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    children: [
                      _NavItem(
                        icon: Icons.dashboard_outlined,
                        label: 'Ringkasan Insiden',
                        selected: currentPath.startsWith('/incidents'),
                        onTap: () => context.go('/incidents'),
                      ),
                      _NavItem(
                        icon: Icons.medical_services_outlined,
                        label: 'Triase',
                        selected: currentPath.startsWith('/triage'),
                        onTap: () => context.go('/triage'),
                      ),
                      _NavItem(
                        icon: Icons.map_outlined,
                        label: 'Peta',
                        selected: currentPath.startsWith('/map'),
                        onTap: () => context.go('/map'),
                      ),
                      _NavItem(
                        icon: Icons.assignment_outlined,
                        label: 'Penugasan',
                        selected: currentPath.startsWith('/assignments'),
                        onTap: () => context.go('/assignments'),
                      ),
                      _NavItem(
                        icon: Icons.campaign_outlined,
                        label: 'Pengumuman',
                        selected: currentPath.startsWith('/announcements'),
                        onTap: () => context.go('/announcements'),
                      ),
                      _NavItem(
                        icon: Icons.home_work_outlined,
                        label: 'Data RT',
                        selected: currentPath.startsWith('/rt-data'),
                        onTap: () => context.go('/rt-data'),
                      ),
                      _NavItem(
                        icon: Icons.school_outlined,
                        label: 'Edukasi',
                        selected: currentPath.startsWith('/education'),
                        onTap: () => context.go('/education'),
                      ),
                      _NavItem(
                        icon: Icons.history_outlined,
                        label: 'Riwayat & Latihan',
                        selected: currentPath.startsWith('/history'),
                        onTap: () => context.go('/history'),
                      ),
                      _NavItem(
                        icon: Icons.summarize_outlined,
                        label: 'Rekap',
                        selected: currentPath.startsWith('/recap'),
                        onTap: () => context.go('/recap'),
                      ),
                      _NavItem(
                        icon: Icons.hub_outlined,
                        label: 'Topologi',
                        selected: currentPath.startsWith('/topology'),
                        onTap: () => context.go('/topology'),
                      ),
                      if (isAdminWilayah)
                        _NavItem(
                          icon: Icons.location_city_outlined,
                          label: 'Wilayah Agregat',
                          selected: currentPath.startsWith('/region'),
                          onTap: () => context.go('/region'),
                        ),
                      if (isOperator)
                        _NavItem(
                          icon: Icons.security_outlined,
                          label: 'Audit Log',
                          selected: currentPath.startsWith('/audit'),
                          onTap: () => context.go('/audit'),
                        ),
                      _NavItem(
                        icon: Icons.router_outlined,
                        label: 'Posko Lokal',
                        selected: currentPath.startsWith('/posko'),
                        onTap: () => context.go('/posko'),
                      ),
                    ],
                  ),
                ),

                // User Profile & Logout Section
                const Divider(color: Color(0xFF1E293B), height: 1),
                Container(
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFF090D16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF2563EB),
                        child: Text(
                          (authState.user?.name.isNotEmpty == true)
                              ? authState.user!.name.substring(0, 1).toUpperCase()
                              : 'U',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              authState.user?.name ?? 'Pengurus',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _formatRole(authState.role),
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, size: 18, color: Color(0xFF94A3B8)),
                        tooltip: 'Keluar',
                        onPressed: () async {
                          await ref.read(authProvider.notifier).logout();
                          if (context.mounted) {
                            context.go('/login');
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Screen Area with Top Header Bar
          Expanded(
            child: Column(
              children: [
                // Top Header Bar
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      // Active RT Selector Dropdown (pemilih RT)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF475569)),
                            const SizedBox(width: 8),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: authState.selectedRT?.id ??
                                    (authState.accessibleRTs.isNotEmpty ? authState.accessibleRTs.first.id : null),
                                hint: const Text(
                                  'Pilih Wilayah RT',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF475569)),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                ),
                                items: authState.accessibleRTs.map((rt) {
                                  return DropdownMenuItem<String>(
                                    value: rt.id,
                                    child: Text(rt.name),
                                  );
                                }).toList(),
                                onChanged: (selectedId) {
                                  if (selectedId != null) {
                                    final match = authState.accessibleRTs.firstWhere((r) => r.id == selectedId);
                                    ref.read(authProvider.notifier).selectRT(match);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Cloud/Posko Connection Status Indicator
                      ConnectionStatusPill(
                        mode: authState.connectionMode,
                        onTap: () {
                          // Quick toggle for testing/simulation
                          final nextMode = authState.connectionMode == 'cloud'
                              ? 'posko'
                              : (authState.connectionMode == 'posko' ? 'offline' : 'cloud');
                          ref.read(authProvider.notifier).setConnectionMode(nextMode);
                        },
                      ),

                      const SizedBox(width: 16),

                      // Role Pill Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Text(
                          _formatRole(authState.role),
                          style: const TextStyle(
                            color: Color(0xFF1D4ED8),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Page View Content
                Expanded(
                  child: Container(
                    color: const Color(0xFFF8FAFC),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatRole(String? role) {
    switch (role) {
      case 'operator':
        return 'Operator Sistem';
      case 'admin_wilayah':
        return 'Admin Wilayah';
      case 'pengurus':
        return 'Pengurus RT';
      case 'relawan':
        return 'Relawan';
      case 'kepala_keluarga':
        return 'Kepala Keluarga';
      default:
        return 'Pengguna';
    }
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF1E293B) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: selected
            ? const Border(left: BorderSide(color: Color(0xFF38BDF8), width: 3))
            : null,
      ),
      child: ListTile(
        dense: true,
        horizontalTitleGap: 8,
        leading: Icon(
          icon,
          size: 18,
          color: selected ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? Colors.white : const Color(0xFFCBD5E1),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
