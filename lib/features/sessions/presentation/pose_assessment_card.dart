import 'package:flutter/material.dart';
import '../../../core/widgets/common.dart';
import '../domain/pose_assessment.dart';

class PoseAssessmentCard extends StatelessWidget {
  const PoseAssessmentCard({super.key, required this.assessment});
  final PoseAssessment assessment;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: AdaptivePair(
      first: MetricCard(
        value: assessment.displayPercent,
        label: 'Pose match',
        icon: Icons.accessibility_new,
      ),
      second: MetricCard(
        value: assessment.rating,
        label: 'Pose rating',
        icon: Icons.fact_check_outlined,
      ),
    ),
  );
}
