import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../app/di/providers.dart';
import '../../../core/widgets/common.dart';
import '../../sessions/domain/therapy_session.dart';

final progressSamplesProvider = FutureProvider.autoDispose
    .family<List<TherapySession>, String>((ref, id) async {
      final sessions = await ref.watch(patientSessionsProvider(id).future);
      return comparableShoulderSamples(sessions);
    });

List<TherapySession> comparableExerciseSamples(
  List<TherapySession> sessions,
  String exerciseId,
) {
  final eligible = sessions.where((s) {
    if (s.exerciseId != exerciseId ||
        (s.analysis != AnalysisStatus.ready && s.trackingQuality != 'High')) {
      return false;
    }
    return switch (exerciseId) {
      'e1' || 'e2' || 'e5' || 'e6' || 'e7' || 'e8' || 'e10' =>
        s.rangeDegrees != null &&
            s.rangeDegrees!.isFinite &&
            s.rangeDegrees! >= 0 &&
            s.rangeDegrees! <= 180,
      'e3' => _valid(s.analysisPayload['stability_percent'], 100),
      'e4' ||
      'e9' => _valid(s.analysisPayload['hold_seconds'], double.infinity),
      _ => false,
    };
  }).toList()..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  if (eligible.isEmpty) return eligible;

  // Keep the newest compatible series instead of letting one side/model switch
  // make all earlier measurements disappear.
  final series = <String, List<TherapySession>>{};
  for (final sample in eligible) {
    final key = [
      sample.analysisPayload['source'] ?? 'legacy',
      sample.analysisPayload['side'] ?? 'unspecified',
      sample.analysisPayload['rule_version'] ?? 'legacy',
      sample.modelVersion ?? 'legacy',
    ].join('|');
    (series[key] ??= []).add(sample);
  }
  return series.values.reduce(
    (a, b) => a.last.startedAt.isAfter(b.last.startedAt) ? a : b,
  );
}

/// Compare only the newest measurement series, never opposite sides or models.
List<TherapySession> comparableShoulderSamples(List<TherapySession> sessions) {
  return comparableExerciseSamples(sessions, 'e1');
}

bool _valid(Object? value, double maximum) =>
    value is num && value.isFinite && value >= 0 && value <= maximum;

const _exercises = [
  ('e1', 'Shoulder reach', 'Movement range', '°'),
  ('e2', 'Seated knee extension', 'Movement range', '°'),
  ('e3', 'Seated balance', 'Balance stability', '%'),
  ('e4', 'Arm hold', 'Hold duration', 's'),
  ('e5', 'Elbow flexion', 'Movement range', '°'),
  ('e6', 'Seated hip flexion', 'Movement range', '°'),
  ('e7', 'Seated knee flexion', 'Movement range', '°'),
  ('e8', 'Shoulder abduction', 'Movement range', '°'),
  ('e9', 'Trunk alignment hold', 'Hold duration', 's'),
  ('e10', 'Sit to stand', 'Movement range', '°'),
];

double _value(TherapySession session) => switch (session.exerciseId) {
  'e3' => (session.analysisPayload['stability_percent'] as num).toDouble(),
  'e4' || 'e9' => (session.analysisPayload['hold_seconds'] as num).toDouble(),
  _ => session.rangeDegrees!,
};
String _format(double value, String unit) =>
    '${value.toStringAsFixed(unit == 's' ? 1 : 0)}$unit';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key, required this.patientId});
  final String patientId;
  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  String? _selectedId;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final patient = ref.watch(patientProvider(widget.patientId)).asData?.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Patient progress')),
      body: PageBody(
        children: [
          Text(
            patient?.name ?? 'Progress overview',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Explore movement across sessions.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          AsyncContent(
            value: ref.watch(patientSessionsProvider(widget.patientId)),
            onRetry: () =>
                ref.invalidate(patientSessionsProvider(widget.patientId)),
            builder: (sessions) {
              final series = {
                for (final e in _exercises)
                  e.$1: comparableExerciseSamples(sessions, e.$1),
              };
              final available = _exercises
                  .where((e) => series[e.$1]!.isNotEmpty)
                  .toList();
              if (available.isEmpty) {
                return const StateMessage(
                  title: 'No comparable measurements',
                  message:
                      'Complete a camera exercise with visible joints and good tracking. Valid measurements will appear here.',
                );
              }
              final selected =
                  available.where((e) => e.$1 == _selectedId).firstOrNull ??
                  available.first;
              final samples = series[selected.$1]!;
              final latest = samples.last;
              final latestDate = sessions
                  .map((s) => s.startedAt)
                  .reduce((a, b) => a.isAfter(b) ? a : b);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${sessions.length} recorded sessions · Latest ${DateFormat('d MMM').format(latestDate.toLocal())}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey('selector-${selected.$1}'),
                    initialValue: selected.$1,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Exercise'),
                    items: [
                      for (final e in available)
                        DropdownMenuItem(
                          value: e.$1,
                          child: Text(
                            e.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() => _selectedId = value),
                  ),
                  const SizedBox(height: 16),
                  ContentCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Latest session',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final items = [
                              _Stat(
                                selected.$3,
                                _format(_value(latest), selected.$4),
                              ),
                              _Stat(
                                'Pose match',
                                latest.poseAssessment.displayPercent,
                              ),
                              _Stat('Rating', latest.poseAssessment.rating),
                            ];
                            if (constraints.maxWidth < 240 ||
                                MediaQuery.textScalerOf(context).scale(14) >
                                    19) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final item in items)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: item,
                                    ),
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (var i = 0; i < items.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 12),
                                  Expanded(child: items[i]),
                                ],
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _TrendCard(
                    key: ValueKey('trend-${selected.$1}'),
                    samples: samples,
                    title: selected.$3,
                    unit: selected.$4,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Showing the latest compatible series for this exercise. Different sides and measurement versions are kept separate.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 4),
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    super.key,
    required this.samples,
    required this.title,
    required this.unit,
  });
  final List<TherapySession> samples;
  final String title, unit;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = samples.length > 12
        ? samples.sublist(samples.length - 12)
        : samples;
    final peak = visible.map(_value).reduce((a, b) => a > b ? a : b);
    final maxY = unit == '°'
        ? 180.0
        : unit == '%'
        ? 100.0
        : ((peak / 5).ceil() * 5).clamp(5, double.infinity).toDouble();
    final interval = maxY / (unit == 's' ? 5 : 4);
    return ContentCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            visible.length == 1
                ? 'First measurement'
                : 'Last ${visible.length} comparable sessions · Tap a point',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          Text(
            _format(_value(visible.last), unit),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text('Latest measurement', style: theme.textTheme.bodySmall),
          const SizedBox(height: 24),
          SizedBox(
            height: 240,
            child: LineChart(
              LineChartData(
                minX: visible.length == 1 ? -1 : 0,
                maxX: visible.length == 1 ? 1 : (visible.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: .5,
                    ),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      interval: interval,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.round()}$unit',
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: visible.length == 1
                          ? 1
                          : ((visible.length - 1) / 2).ceilToDouble(),
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if (index < 0 ||
                            index >= visible.length ||
                            value != index.toDouble()) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            DateFormat(
                              'd/M',
                            ).format(visible[index].startedAt.toLocal()),
                            style: theme.textTheme.labelSmall,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (spots) => spots.map((spot) {
                      final session = visible[spot.spotIndex];
                      return LineTooltipItem(
                        '${DateFormat('d MMM · HH:mm').format(session.startedAt.toLocal())}\n${_format(spot.y, unit)}',
                        theme.textTheme.bodySmall!.copyWith(
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < visible.length; i++)
                        FlSpot(i.toDouble(), _value(visible[i])),
                    ],
                    isCurved: false,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    color: theme.colorScheme.primary,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                            radius: index == visible.length - 1 ? 5 : 3.5,
                            color: theme.colorScheme.surface,
                            strokeWidth: 2.5,
                            strokeColor: theme.colorScheme.primary,
                          ),
                    ),
                    belowBarData: BarAreaData(
                      show: visible.length > 1,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: .20),
                          theme.colorScheme.primary.withValues(alpha: .01),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            visible.length == 1
                ? 'Your first measurement is shown above. Complete another comparable session to see a trend.'
                : 'Sessions shown in order; spacing does not represent elapsed time.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
