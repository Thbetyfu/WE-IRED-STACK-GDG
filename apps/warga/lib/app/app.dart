import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import 'routes.dart';

class WargaApp extends ConsumerWidget {
  const WargaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(wargaRouterProvider);

    return MaterialApp.router(
      title: 'WE-IRED Warga',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
