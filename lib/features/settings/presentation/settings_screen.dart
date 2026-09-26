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
    final title = displayName == null || displayName.isEmpty
        ? user?.email
        : displayName;

    return PageBody(
      children: [
        const PageHeading(
          'Your workspace',
          'Your profile and account preferences.',
        ),
        ContentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // CircleAvatar(
              //   radius: 30,
              //   backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              //   foregroundColor: Theme.of(context).colorScheme.primary,
              //   child: const Icon(Icons.person_outline_rounded, size: 32),
              // ),
              // const SizedBox(height: 16),
              // StatusBadge(
              //   user != null ? 'Therapist account' : 'Not signed in',
              //   tone: user != null ? StatusTone.success : StatusTone.info,
              // ),
              // const SizedBox(height: 16),
              Text(
                title ?? 'Sign in to your account',
                style: Theme.of(context).textTheme.titleLarge,
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
             
            ],
          ),
        ),
        const SectionHeading('About your workspace'),
        const ContentCard(
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.accessibility_new_rounded),
                title: Text('Movement tracking'),
                subtitle: Text(
                  'Camera-guided exercises with session summaries.',
                ),
              ),
              Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.insights_rounded),
                title: Text('Patient progress'),
                subtitle: Text(
                  'Compare recorded measurements and review each session.',
                ),
              ),
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
          label: const Text('Sign out'),
        ),
      ],
    );
  }
}