import 'package:flutter/material.dart';

abstract final class AppSpace {
  static const small = 8.0, medium = 16.0, section = 24.0;
}

enum StatusTone { info, success, warning, error }

@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    this.success = const Color(0xFF166534),
    this.successSurface = const Color(0xFFDCFCE7),
    this.warning = const Color(0xFF92400E),
    this.warningSurface = const Color(0xFFFEF3C7),
    this.info = const Color(0xFF1D4ED8),
    this.infoSurface = const Color(0xFFEFF6FF),
  });
  final Color success,
      successSurface,
      warning,
      warningSurface,
      info,
      infoSurface;
  @override
  StatusColors copyWith({
    Color? success,
    Color? successSurface,
    Color? warning,
    Color? warningSurface,
    Color? info,
    Color? infoSurface,
  }) => StatusColors(
    success: success ?? this.success,
    successSurface: successSurface ?? this.successSurface,
    warning: warning ?? this.warning,
    warningSurface: warningSurface ?? this.warningSurface,
    info: info ?? this.info,
    infoSurface: infoSurface ?? this.infoSurface,
  );
  @override
  StatusColors lerp(covariant StatusColors? other, double t) => other == null
      ? this
      : StatusColors(
          success: Color.lerp(success, other.success, t)!,
          successSurface: Color.lerp(successSurface, other.successSurface, t)!,
          warning: Color.lerp(warning, other.warning, t)!,
          warningSurface: Color.lerp(warningSurface, other.warningSurface, t)!,
          info: Color.lerp(info, other.info, t)!,
          infoSurface: Color.lerp(infoSurface, other.infoSurface, t)!,
        );
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E))
      .copyWith(
        primary: const Color(0xFF0F766E),
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFCCFBF1),
        onPrimaryContainer: const Color(0xFF134E4A),
        surface: const Color(0xFFF7FAFC),
        surfaceContainerLow: Colors.white,
        onSurface: const Color(0xFF172B3A),
        onSurfaceVariant: const Color(0xFF526473),
        outline: const Color(0xFF64748B),
        outlineVariant: const Color(0xFFDCE5EA),
        error: const Color(0xFFB42318),
        errorContainer: const Color(0xFFFEE4E2),
      );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    fontFamily: 'Roboto',
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  return base.copyWith(
    extensions: const [StatusColors()],
    textTheme: base.textTheme
        .copyWith(
          headlineMedium: const TextStyle(
            fontSize: 28,
            height: 36 / 28,
            fontWeight: FontWeight.w600,
          ),
          titleLarge: const TextStyle(
            fontSize: 22,
            height: 28 / 22,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: const TextStyle(
            fontSize: 18,
            height: 26 / 18,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: const TextStyle(fontSize: 16, height: 1.5),
          bodyMedium: const TextStyle(fontSize: 14, height: 20 / 14),
          labelLarge: const TextStyle(
            fontSize: 14,
            height: 20 / 14,
            fontWeight: FontWeight.w500,
          ),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: shape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: shape,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: scheme.primaryContainer,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
