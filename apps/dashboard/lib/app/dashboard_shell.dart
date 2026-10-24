import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import 'package:ui/ui.dart';

import 'auth_provider.dart';

class DashboardShell extends ConsumerStatefulWidget {
  final Widget child;

  const DashboardShell({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool? _userSidebarPreference; // null = auto by breakpoint, true = collapsed, false = expanded

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    String currentPath = '/incidents';
    try {
      currentPath = GoRouterState.of(context).uri.toString();
    } catch (_) {
      // Fallback for widget testing outside full GoRouter hierarchy
      currentPath = '/incidents';
    }

    final isOperator = authState.role == 'operator';
    final isAdminWilayah = authState.role == 'admin_wilayah' || isOperator;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isMobile = screenWidth < 768;
        final isTablet = screenWidth >= 768 && screenWidth < 1120;

        // Auto-collapse on tablet unless user explicitly overrode it
        final isCollapsed = _userSidebarPreference ?? isTablet;

        return Scaffold(
          key: _scaffoldKey,
          drawer: isMobile
              ? Drawer(
                  backgroundColor: const Color(0xFF0F172A),
                  child: _SidebarContent(
                    isCollapsed: false,
                    currentPath: currentPath,
                    isAdminWilayah: isAdminWilayah,
                    isOperator: isOperator,
                    authState: authState,
                    onNavigate: (route) {
                      Navigator.of(context).pop(); // close drawer
                      try {
                        context.go(route);
                      } catch (_) {}
                    },
                    onToggleCollapse: null,
                    onLogout: () => _handleLogout(context),
                  ),
                )
              : null,
          body: Row(
            children: [
              // Sidebar Navigation (Hidden in mobile drawer)
              if (!isMobile)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  width: isCollapsed ? 70 : 240,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F172A), // Dark slate
                    border: Border(right: BorderSide(color: Color(0xFF1E293B))),
                  ),
                  child: _SidebarContent(
                    isCollapsed: isCollapsed,
                    currentPath: currentPath,
                    isAdminWilayah: isAdminWilayah,
                    isOperator: isOperator,
                    authState: authState,
                    onNavigate: (route) {
                      try {
                        context.go(route);
                      } catch (_) {}
                    },
                    onToggleCollapse: () {
                      setState(() {
                        _userSidebarPreference = !isCollapsed;
                      });
                    },
                    onLogout: () => _handleLogout(context),
                  ),
                ),

              // Main Application View Area
              Expanded(
                child: Column(
                  children: [
                    // Top Command Header
                    _TopCommandHeader(
                      authState: authState,
                      isMobile: isMobile,
                      isCollapsed: isCollapsed,
                      onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                      onToggleSidebar: () {
                        setState(() {
                          _userSidebarPreference = !isCollapsed;
                        });
                      },
                      onSelectRT: (rt) {
                        ref.read(authProvider.notifier).selectRT(rt);
                      },
                      onToggleConnectionMode: () {
                        final nextMode = authState.connectionMode == 'cloud'
                            ? 'posko'
                            : (authState.connectionMode == 'posko' ? 'offline' : 'cloud');
                        ref.read(authProvider.notifier).setConnectionMode(nextMode);
                      },
                    ),

                    // Main Content Canvas
                    Expanded(
                      child: Container(
                        color: const Color(0xFFF8FAFC),
                        child: widget.child,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    await ref.read(authProvider.notifier).logout();
    if (context.mounted) {
      try {
        context.go('/login');
      } catch (_) {}
    }
  }
}

class _SidebarContent extends StatelessWidget {
  final bool isCollapsed;
  final String currentPath;
  final bool isAdminWilayah;
  final bool isOperator;
  final AuthState authState;
  final ValueChanged<String> onNavigate;
  final VoidCallback? onToggleCollapse;
  final VoidCallback onLogout;

  const _SidebarContent({
    required this.isCollapsed,
    required this.currentPath,
    required this.isAdminWilayah,
    required this.isOperator,
    required this.authState,
    required this.onNavigate,
    required this.onToggleCollapse,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final collapsed = isCollapsed || constraints.maxWidth < 140;

        return Column(
          children: [
            // Brand Header
            Container(
              height: 64,
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 8 : 14),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: collapsed
                  ? Center(
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.shield, color: Colors.white, size: 18),
                      ),
                    )
                  : Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.shield, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'WE-IRED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Posko & RT Command',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (onToggleCollapse != null)
                          IconButton(
                            icon: const Icon(Icons.menu_open, color: Color(0xFF94A3B8), size: 18),
                            tooltip: 'Ciutkan Sidebar',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            visualDensity: VisualDensity.compact,
                            onPressed: onToggleCollapse,
                          ),
                      ],
                    ),
            ),

            // Navigation Items List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                children: [
                  if (!collapsed) _buildSectionHeader('OPERASI INSIDEN'),
                  _NavTile(
                    icon: Icons.dashboard_outlined,
                    label: 'Ringkasan Insiden',
                    selected: currentPath.startsWith('/incidents'),
                    isCollapsed: collapsed,
                    onTap: () => onNavigate('/incidents'),
                  ),
                  _NavTile(
                    icon: Icons.medical_services_outlined,
                    label: 'Triase & Prioritas',
                    selected: currentPath.startsWith('/triage'),
                    isCollapsed: collapsed,
                    onTap: () => onNavigate('/triage'),
                  ),
                  _NavTile(
                    icon: Icons.map_outlined,
                    label: 'Peta Spasial',
                    selected: currentPath.startsWith('/map'),
                    isCollapsed: collapsed,
                    onTap: () => onNavigate('/map'),
                  ),
                  _NavTile(
                    icon: Icons.assignment_outlined,
                    label: 'Penugasan Relawan',
                    selected: currentPath.startsWith('/assignments'),
                    isCollapsed: collapsed,
                    onTap: () => onNavigate('/assignments'),
                  ),
                  _NavTile(
                    icon: Icons.campaign_outlined,
                    label: 'Siaran Pengumuman',
                    selected: currentPath.startsWith('/announcements'),
                    isCollapsed: collapsed,
                    onTap: () => onNavigate('/announcements'),
                  ),

                  const SizedBox(height: 12),
                  if (!collapsed) _buildSectionHeader('MANAJEMEN WILAYAH'),
                  _NavTile(
                    icon: Icons.home_work_outlined,
                    label: 'Data Master RT',
                    selected: currentPath.startsWith('/rt-data'),
                    isCollapsed: collapsed,
                    onTap: () => onNavigate('/rt-data'),
                  ),
                  _NavTile(
                    icon: Icons.school_outlined,
                    label: 'Edukasi Siaga',
                    selected: currentPath.startsWith('/education'),
                    isCollapsed: collapsed,
                    onTap: () => onNavigate('/education'),
                  ),
                  _NavTile(
                    icon: Icons.history_outlined,
                    label: 'Riwayat & Latihan',
                    selected: currentPath.startsWith('/history'),
                    isCollapsed: collapsed,
                    onTap: () => onNavigate('/history'),
                  ),
                  _NavTile(
                    icon: Icons.summarize_outlined,
                    label: 'Rekapitulasi',
                    selected: currentPath.startsWith('/recap'),
                    isCollapsed: collapsed,
                    onTap: () => onNavigate('/recap'),
                  ),

                  const SizedBox(height: 12),
                  if (!collapsed) _buildSectionHeader('SISTEM & JARINGAN'),
                  _NavTile(
                    icon: Icons.hub_outlined,
                    label: 'Topologi Mesh',
                    selected: currentPath.startsWith('/topology'),
                    isCollapsed: collapsed,
                    onTap: () => onNavigate('/topology'),
                  ),
                  if (isAdminWilayah)
                    _NavTile(
                      icon: Icons.location_city_outlined,
                      label: 'Wilayah Agregat',
                      selected: currentPath.startsWith('/region'),
                      isCollapsed: collapsed,
                      onTap: () => onNavigate('/region'),
                    ),
                  if (isOperator)
                    _NavTile(
                      icon: Icons.security_outlined,
                      label: 'Audit Trail',
                      selected: currentPath.startsWith('/audit'),
                      isCollapsed: collapsed,
                      onTap: () => onNavigate('/audit'),
                    ),
                  _NavTile(
                    icon: Icons.router_outlined,
                    label: 'Posko Lokal',
                    selected: currentPath.startsWith('/posko'),
                    isCollapsed: collapsed,
                    onTap: () => onNavigate('/posko'),
                  ),
                ],
              ),
            ),

            // User Profile & Logout Bottom Bar
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF090D16),
                border: Border(top: BorderSide(color: Color(0xFF1E293B))),
              ),
              padding: EdgeInsets.all(collapsed ? 10 : 12),
              child: collapsed
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Tooltip(
                          message: '${authState.user?.name ?? "Pengurus"} (${_formatRole(authState.role)})',
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFF2563EB),
                            child: Text(
                              (authState.user?.name.isNotEmpty == true)
                                  ? authState.user!.name.substring(0, 1).toUpperCase()
                                  : 'U',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        IconButton(
                          icon: const Icon(Icons.logout, size: 18, color: Color(0xFF94A3B8)),
                          tooltip: 'Keluar',
                          onPressed: onLogout,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        CircleAvatar(
                          radius: 17,
                          backgroundColor: const Color(0xFF2563EB),
                          child: Text(
                            (authState.user?.name.isNotEmpty == true)
                                ? authState.user!.name.substring(0, 1).toUpperCase()
                                : 'U',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                authState.user?.name ?? 'Pengurus RT',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatRole(authState.role),
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout, size: 18, color: Color(0xFF94A3B8)),
                          tooltip: 'Keluar',
                          onPressed: onLogout,
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, top: 8, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  static String _formatRole(String? role) {
    switch (role) {
      case 'operator':
        return 'Operator Sistem';
      case 'admin_wilayah':
        return 'Admin Wilayah';
      case 'pengurus':
        return 'Pengurus RT';
      case 'relawan':
        return 'Relawan Lapangan';
      case 'kepala_keluarga':
        return 'Warga / Kepala Keluarga';
      default:
        return 'Pengguna Sistem';
    }
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool isCollapsed;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.isCollapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = const Color(0xFF1E293B);
    final activeFg = const Color(0xFF38BDF8);
    final inactiveFg = const Color(0xFF94A3B8);

    if (isCollapsed) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        child: Tooltip(
          message: label,
          waitDuration: const Duration(milliseconds: 200),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: selected ? activeBg : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: selected ? Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.4)) : null,
              ),
              child: Icon(
                icon,
                size: 20,
                color: selected ? activeFg : inactiveFg,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: selected ? activeBg : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: selected
            ? const Border(left: BorderSide(color: Color(0xFF38BDF8), width: 3))
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? activeFg : inactiveFg,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? Colors.white : const Color(0xFFCBD5E1),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopCommandHeader extends StatelessWidget {
  final AuthState authState;
  final bool isMobile;
  final bool isCollapsed;
  final VoidCallback onOpenDrawer;
  final VoidCallback onToggleSidebar;
  final ValueChanged<Region> onSelectRT;
  final VoidCallback onToggleConnectionMode;

  const _TopCommandHeader({
    required this.authState,
    required this.isMobile,
    required this.isCollapsed,
    required this.onOpenDrawer,
    required this.onToggleSidebar,
    required this.onSelectRT,
    required this.onToggleConnectionMode,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 620;

        return Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              // Left Sidebar Toggle button
              if (isMobile)
                IconButton(
                  icon: const Icon(Icons.menu, color: Color(0xFF334155)),
                  tooltip: 'Buka Menu',
                  onPressed: onOpenDrawer,
                )
              else if (isCollapsed)
                IconButton(
                  icon: const Icon(Icons.menu, color: Color(0xFF334155), size: 20),
                  tooltip: 'Perluas Sidebar',
                  onPressed: onToggleSidebar,
                ),

              if (isMobile || isCollapsed) const SizedBox(width: 8),

              // Wilayah / RT Selector Dropdown
              Flexible(
                child: _buildRegionSelector(context, isCompact: isCompact),
              ),

              const SizedBox(width: 8),
              const Spacer(),

              // Connection Mode Status Pill (Cloud / Posko / Offline)
              ConnectionStatusPill(
                mode: authState.connectionMode,
                onTap: onToggleConnectionMode,
              ),

              if (!isCompact) ...[
                const SizedBox(width: 10),
                // Role Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Text(
                    _SidebarContent._formatRole(authState.role),
                    style: const TextStyle(
                      color: Color(0xFF1D4ED8),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRegionSelector(BuildContext context, {bool isCompact = false}) {
    final accessibleRTs = authState.accessibleRTs;
    final selectedRT = authState.selectedRT ?? (accessibleRTs.isNotEmpty ? accessibleRTs.first : null);

    return Container(
      constraints: BoxConstraints(maxWidth: isCompact ? 170 : 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF2563EB)),
          const SizedBox(width: 6),
          if (accessibleRTs.length <= 1)
            Flexible(
              child: Text(
                selectedRT?.name ?? 'Wilayah RT',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )
          else
            Flexible(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedRT?.id,
                  isDense: true,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF475569), size: 18),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  items: accessibleRTs.map((rt) {
                    return DropdownMenuItem<String>(
                      value: rt.id,
                      child: Text(rt.name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (selectedId) {
                    if (selectedId != null) {
                      final match = accessibleRTs.firstWhere((r) => r.id == selectedId);
                      onSelectRT(match);
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
