import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'warga_state.dart';
import 'warga_shell.dart';
import '../features/home/home_page.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/report/report_page.dart';
import '../features/household/household_page.dart';
import '../features/education/education_page.dart';
import '../features/first_aid/first_aid_page.dart';
import '../features/announcements/announcements_page.dart';
import '../features/settings/settings_page.dart';

final wargaRouterProvider = Provider<GoRouter>((ref) {
  final wargaState = ref.watch(wargaProvider);

  return GoRouter(
    initialLocation: wargaState.isAuthenticated ? '/' : '/onboarding',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return WargaShell(
            currentPath: state.uri.path,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: '/announcements',
            builder: (context, state) => const AnnouncementsPage(),
          ),
          GoRoute(
            path: '/education',
            builder: (context, state) => const EducationPage(),
          ),
          GoRoute(
            path: '/household',
            builder: (context, state) => const HouseholdPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/report',
        builder: (context, state) => const ReportPage(),
      ),
      GoRoute(
        path: '/first_aid',
        builder: (context, state) => const FirstAidPage(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
});
