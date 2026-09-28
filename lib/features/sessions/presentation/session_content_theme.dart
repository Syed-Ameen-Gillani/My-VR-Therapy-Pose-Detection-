import 'package:flutter/material.dart';

/// Slightly smaller typography for the summary and saved session results.
/// System accessibility text scaling continues to apply normally.
class SessionContentTheme extends StatelessWidget {
  const SessionContentTheme({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(fontSizeFactor: 0.9),
      ),
      child: Builder(builder: builder),
    );
  }
}
