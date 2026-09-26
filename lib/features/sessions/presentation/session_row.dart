import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../domain/therapy_session.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/common.dart';

String analysisLabel(AnalysisStatus status) => switch (status) {
  AnalysisStatus.ready => 'Analysis ready',
  AnalysisStatus.pending => 'Analysis pending',
  AnalysisStatus.incomplete => 'Tracking incomplete',
  AnalysisStatus.failed => 'Analysis failed',
};

class SessionRow extends StatelessWidget {
  const SessionRow({super.key, required this.session, required this.title});
  final TherapySession session;
  final String title;
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: () => context.push('/sessions/${session.id}'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF94A3B8),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${DateFormat('d MMM').format(session.startedAt)} • ${session.durationMinutes} min • ${session.repetitions} repetitions',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          if (session.poseAssessment.percent != null) ...[
            Text(
              'Pose match: ${session.poseAssessment.displayPercent} · ${session.poseAssessment.rating}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
          ],
          StatusBadge(
            session.reviewed ? 'Reviewed' : analysisLabel(session.analysis),
            tone: session.reviewed
                ? StatusTone.success
                : session.analysis == AnalysisStatus.incomplete
                ? StatusTone.warning
                : StatusTone.info,
          ),
        ],
      ),
    ),
  );
}
