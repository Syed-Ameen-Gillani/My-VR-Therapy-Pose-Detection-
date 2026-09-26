import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import 'app.dart';

void bootstrap() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      _installReleaseErrorGuards();
      try {
        await Supabase.initialize(
          url: SupabaseConfig.url,
          publishableKey: SupabaseConfig.anonKey,
        );
        runApp(const ProviderScope(child: TherapyApp()));
      } catch (error, stackTrace) {
        _reportStartupError(error, stackTrace);
      }
    },
    _reportStartupError,
  );
}

void _installReleaseErrorGuards() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _showFailureApp(details.exception);
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    _reportStartupError(error, stackTrace);
    return true;
  };

  ErrorWidget.builder = (details) =>
      StartupFailureView(error: details.exception);
}

void _reportStartupError(Object error, StackTrace? stackTrace) {
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stackTrace,
      library: 'app bootstrap',
    ),
  );
  _showFailureApp(error);
}

void _showFailureApp(Object error) {
  runApp(StartupFailureApp(error: error));
}

class StartupFailureView extends StatelessWidget {
  const StartupFailureView({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF3F7F8),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFB91C1C),
                    size: 44,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'App could not start',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please check internet access and app configuration, then reopen the app.',
                    style: TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SelectableText(
                    error.toString(),
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StartupFailureView(error: error),
    );
  }
}
