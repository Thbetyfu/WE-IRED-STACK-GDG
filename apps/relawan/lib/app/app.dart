import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import 'routes.dart';

class RelawanApp extends ConsumerWidget {
  const RelawanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(relawanRouterProvider);

    return MaterialApp.router(
      title: 'WE-IRED Relawan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
