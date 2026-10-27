import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/realtime/realtime_binder.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class DatingCloudApp extends ConsumerWidget {
  const DatingCloudApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Dating Cloud',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) =>
          RealtimeBinder(child: child ?? const SizedBox.shrink()),
    );
  }
}

/// Shown instead of the app when [AppConfig] validation fails at startup.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Invalid app configuration\n\n$message',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ),
  );
}
