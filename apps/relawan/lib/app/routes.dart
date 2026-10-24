import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'relawan_shell.dart';
import '../features/tasks/tasks_page.dart';
import '../features/block_map/block_map_page.dart';
import '../features/proxy_report/proxy_report_page.dart';
import '../features/collector/collector_page.dart';
import '../features/posko/posko_connect_page.dart';
import '../features/topology/topology_view_page.dart';
import '../features/beacon_tools/beacon_tools_page.dart';
import '../features/first_aid/first_aid_reference_page.dart';

final relawanRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/tasks',
    routes: [
      ShellRoute(
        builder: (context, state, child) => RelawanShell(child: child),
        routes: [
          GoRoute(
            path: '/tasks',
            builder: (context, state) => const TasksPage(),
          ),
          GoRoute(
            path: '/block_map',
            builder: (context, state) => const BlockMapPage(),
          ),
          GoRoute(
            path: '/proxy_report',
            builder: (context, state) => const ProxyReportPage(),
          ),
          GoRoute(
            path: '/collector',
            builder: (context, state) => const CollectorPage(),
          ),
          GoRoute(
            path: '/posko',
            builder: (context, state) => const PoskoConnectPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/topology',
        builder: (context, state) => const TopologyViewPage(),
      ),
      GoRoute(
        path: '/beacon_tools',
        builder: (context, state) => const BeaconToolsPage(),
      ),
      GoRoute(
        path: '/first_aid',
        builder: (context, state) => const FirstAidReferencePage(),
      ),
    ],
  );
});
