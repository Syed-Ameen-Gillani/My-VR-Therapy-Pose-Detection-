import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/di/providers.dart';
import '../../../core/widgets/common.dart';
import '../domain/therapy_session.dart';
import 'session_row.dart';

class SessionHistoryScreen extends ConsumerWidget {
  const SessionHistoryScreen({super.key, required this.patientId});
  final String patientId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Session history')),
    body: PageBody(
      children: [
        const PageHeading(
          'One session at a time',
          'Sample results, ordered by most recent.',
        ),
        AsyncContent(
          value: ref.watch(patientSessionsProvider(patientId)),
          onRetry: () => ref.invalidate(sessionsProvider),
          builder: (sessions) => Column(
            children: [
              if (sessions.isEmpty)
                const StateMessage(
                  title: 'No sessions yet',
                  message: 'Uploaded sessions will appear here.',
                ),
              for (final s in sessions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: SessionRow(session: s, title: 'Movement session'),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class SessionDetailScreen extends ConsumerStatefulWidget {
  const SessionDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<SessionDetailScreen> createState() =>
      _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  final _reviewController = TextEditingController();
  bool _isSaving = false;
  String? _errorText;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _saveReview() async {
    if (_isSaving) return;
    final note = _reviewController.text.trim();
    if (note.isEmpty) {
      setState(() => _errorText = 'Write a short review note before saving.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      await ref
          .read(sessionRepositoryProvider)
          .saveReview(sessionId: widget.id, note: note);
      ref.invalidate(sessionsProvider);
      if (!mounted) return;
      _reviewController.clear();
      setState(() => _isSaving = false);
      showPhaseNotice(context, 'Therapist review saved.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorText = 'Could not save review: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Session results')),
    body: PageBody(
      children: [
        AsyncContent(
          value: ref.watch(sessionsProvider),
          onRetry: () => ref.invalidate(sessionsProvider),
          builder: (sessions) {
            final session = sessions
                .where((s) => s.id == widget.id)
                .firstOrNull;
            if (session == null) {
              return const StateMessage(
                title: 'Session not found',
                message: 'Choose an available session from the patient record.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeading(
                  'Movement session',
                  '${DateFormat('d MMMM yyyy · HH:mm').format(session.startedAt)} UTC · Sample data',
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    const StatusBadge('Session completed'),
                    StatusBadge(
                      session.reviewed
                          ? 'Reviewed'
                          : analysisLabel(session.analysis),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                AdaptivePair(
                  first: MetricCard(
                    value: '${session.durationMinutes} min',
                    label: 'Session duration',
                    icon: Icons.timer_outlined,
                  ),
                  second: MetricCard(
                    value: '${session.repetitions}',
                    label: 'Repetitions',
                    icon: Icons.repeat,
                  ),
                ),
                const SectionHeading('Movement analysis'),
                ContentCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.rangeDegrees == null
                            ? 'Measurement unavailable'
                            : '${session.rangeDegrees!.toStringAsFixed(0)}° shoulder range',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(switch (session.analysis) {
                        AnalysisStatus.ready =>
                          'Sample measurement from a simulated session. This value is not a clinical assessment.',
                        AnalysisStatus.pending =>
                          'Analysis is still processing. No movement score is available yet.',
                        AnalysisStatus.incomplete =>
                          'Tracking was incomplete. Missing measurements are not treated as zero.',
                        AnalysisStatus.failed =>
                          'Analysis could not be completed. Session completion is still recorded.',
                      }),
                    ],
                  ),
                ),
                const SectionHeading('AI feedback'),
                ContentCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.aiFeedback ??
                            'No AI feedback is available for this session yet.',
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (session.trackingQuality != null)
                            StatusBadge('Tracking ${session.trackingQuality}'),
                          if (session.modelVersion != null)
                            StatusBadge('Model ${session.modelVersion}'),
                          if (session.aiFeedback == null &&
                              session.trackingQuality == null &&
                              session.modelVersion == null)
                            const StatusBadge('Feedback unavailable'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SectionHeading('Therapist review'),
                TextField(
                  controller: _reviewController,
                  minLines: 3,
                  maxLines: 6,
                  textAlignVertical: TextAlignVertical.top,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(
                    hintText: 'Review note',
                    alignLabelWithHint: true,
                  ),
                ),
                if (_errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      _errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _isSaving ? null : _saveReview,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save review',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
