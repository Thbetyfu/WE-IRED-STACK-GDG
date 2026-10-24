import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_provider.dart';
import 'dashboard_shell.dart';

import '../features/auth/login_page.dart';
import '../features/incident_overview/incident_overview_page.dart';
import '../features/triage/triage_page.dart';
import '../features/map/map_page.dart';
import '../features/assignments/assignments_page.dart';
import '../features/announcements/announcements_page.dart';
import '../features/rt_data/rt_data_page.dart';
import '../features/education/education_page.dart';
import '../features/history_drills/history_page.dart';
import '../features/recap/recap_page.dart';
import '../features/topology/topology_page.dart';
import '../features/region/region_page.dart';
import '../features/audit/audit_page.dart';
import '../features/posko/posko_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/incidents',
    redirect: (context, state) {
      final isLoggingIn = state.uri.path == '/login';

      // 1. Unauthenticated users must log in
      if (!authState.isAuthenticated) {
        return isLoggingIn ? null : '/login';
      }

      // 2. Already logged in users visiting /login get redirected to /incidents
      if (isLoggingIn) {
        return '/incidents';
      }

      // 3. Role-based route guards
      final role = authState.role;
      final path = state.uri.path;

      // Wilayah page requires admin_wilayah or operator
      if (path.startsWith('/region')) {
        if (role != 'admin_wilayah' && role != 'operator') {
          return '/incidents';
        }
      }

      // Audit page requires operator
      if (path.startsWith('/audit')) {
        if (role != 'operator') {
          return '/incidents';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => DashboardShell(child: child),
        routes: [
          GoRoute(
            path: '/incidents',
            builder: (context, state) => const IncidentOverviewPage(),
          ),
          GoRoute(
            path: '/triage',
            builder: (context, state) => const TriagePage(),
          ),
          GoRoute(
            path: '/map',
            builder: (context, state) => const MapPage(),
          ),
          GoRoute(
            path: '/assignments',
            builder: (context, state) => const AssignmentsPage(),
          ),
          GoRoute(
            path: '/announcements',
            builder: (context, state) => const AnnouncementsPage(),
          ),
          GoRoute(
            path: '/rt-data',
            builder: (context, state) => const RtDataPage(),
          ),
          GoRoute(
            path: '/education',
            builder: (context, state) => const EducationPage(),
          ),
          GoRoute(
            path: '/history',
            builder: (context, state) => const HistoryPage(),
          ),
          GoRoute(
            path: '/recap',
            builder: (context, state) => const RecapPage(),
          ),
          GoRoute(
            path: '/topology',
            builder: (context, state) => const TopologyPage(),
          ),
          GoRoute(
            path: '/region',
            builder: (context, state) => const RegionPage(),
          ),
          GoRoute(
            path: '/audit',
            builder: (context, state) => const AuditPage(),
          ),
          GoRoute(
            path: '/posko',
            builder: (context, state) => const PoskoPage(),
          ),
        ],
      ),
    ],
  );
});
