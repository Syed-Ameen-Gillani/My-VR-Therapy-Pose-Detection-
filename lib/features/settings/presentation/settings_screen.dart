import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/common.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isSigningOut = false;

  void _clearWorkspaceData() {
    ref.invalidate(patientsProvider);
    ref.invalidate(exercisesProvider);
    ref.invalidate(sessionsProvider);
    ref.invalidate(plansProvider);
  }

  Future<void> _leaveWorkspace() async {
    if (_isSigningOut) return;

    setState(() => _isSigningOut = true);
    final user = ref.read(currentUserProvider);

    try {
      if (user != null) {
        await ref.read(authRepositoryProvider).signOut();
      }
      _clearWorkspaceData();
      ref.read(demoAccessProvider.notifier).leave();
    } catch (_) {
      if (!mounted) return;
      showPhaseNotice(context, 'Could not sign out. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final displayName = user?.displayName?.trim();
    final title =
        displayName == null || displayName.isEmpty ? user?.email : displayName;

    return PageBody(
      children: [
        const PageHeading(
          'Your workspace',
          'A simple foundation for thoughtful care.',
        ),
        ContentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusBadge(
                user != null ? 'Authenticated Therapist' : 'Demo therapist',
                tone: user != null ? StatusTone.success : StatusTone.info,
              ),
              const SizedBox(height: 16),
              Text(
                title ?? 'Demo therapist',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (user != null && title != user.email) ...[
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                user != null
                    ? 'Connected to Supabase PostgreSQL with Row-Level Security enabled.'
                    : 'All patients and measurements are fictional sample records.',
              ),
              const SizedBox(height: 12),
              const Text('MY VR Therapy - Phase 2 Active'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _isSigningOut ? null : _leaveWorkspace,
          icon: _isSigningOut
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout),
          label: Text(user != null ? 'Sign out' : 'Leave demo'),
        ),
      ],
    );
  }
}
