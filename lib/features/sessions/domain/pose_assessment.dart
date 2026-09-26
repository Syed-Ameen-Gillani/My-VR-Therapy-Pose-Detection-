/// Exercise-rule match, separate from ML Kit landmark visibility likelihood.
class PoseAssessment {
  const PoseAssessment(this.percent);
  final double? percent;

  factory PoseAssessment.fromPayload(Map<String, Object?> payload) {
    final value = payload['pose_match_percent'];
    return PoseAssessment(
      value is num && value.isFinite && value >= 0 && value <= 100
          ? value.toDouble()
          : null,
    );
  }

  String get rating => percent == null
      ? 'Not available'
      : percent! >= 95
      ? 'Outstanding'
      : percent! >= 85
      ? 'Excellent'
      : percent! >= 75
      ? 'Good'
      : percent! >= 60
      ? 'Average'
      : percent! >= 45
      ? 'Fair'
      : percent! >= 30
      ? 'Poor'
      : 'Very Poor';

  String get displayPercent => percent == null
      ? 'Not available'
      : '${percent!.toStringAsFixed(1)}%';
}
