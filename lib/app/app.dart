import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class TherapyApp extends ConsumerWidget {
  const TherapyApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'MY VR Therapy',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    routerConfig: ref.watch(routerProvider),
  );
}
