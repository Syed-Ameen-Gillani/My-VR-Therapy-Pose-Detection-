import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/therapy_session.dart';

class SupabaseSessionRepository implements SessionRepository {
  SupabaseSessionRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<TherapySession>> getSessions() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const AppFailure('Authentication required to view sessions.');
      }

      final data = await _client
          .from('sessions')
          .select('*, session_reviews!left(therapist_id)')
          .eq('therapist_id', user.id)
          .order('started_at', ascending: false);

      return (data as List<dynamic>)
          .map((row) => _mapRowToSession(row as Map<String, dynamic>))
          .toList();
    } on AppFailure {
      rethrow;
    } catch (e) {
      throw AppFailure('Failed to load therapy sessions: $e');
    }
  }

  @override
  Future<void> saveReview({
    required String sessionId,
    required String note,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const AppFailure('Authentication required to save review.');
      }

      await _client.from('session_reviews').upsert({
        'session_id': sessionId,
        'therapist_id': user.id,
        'note': note.trim(),
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'session_id,therapist_id');
    } on AppFailure {
      rethrow;
    } catch (e) {
      throw AppFailure('Failed to save therapist review: $e');
    }
  }

  TherapySession _mapRowToSession(Map<String, dynamic> map) {
    final analysisPayload = map['analysis_payload'] is Map
        ? Map<String, dynamic>.from(map['analysis_payload'] as Map)
        : const <String, dynamic>{};
    return TherapySession(
      id: map['id'] as String,
      patientId: map['patient_id'] as String,
      exerciseId: map['exercise_id'] as String,
      startedAt: DateTime.parse(map['started_at'] as String).toUtc(),
      durationMinutes: (map['duration_minutes'] as num?)?.round() ?? 0,
      repetitions: (map['repetitions'] as num?)?.round() ?? 0,
      analysis: _mapAnalysisStatus(map['analysis_status'] as String?),
      rangeDegrees: (map['range_degrees'] as num?)?.toDouble(),
      aiFeedback: _stringValue(analysisPayload['feedback']),
      trackingQuality: _stringValue(analysisPayload['tracking_quality']),
      modelVersion: _stringValue(analysisPayload['model_version']),
      reviewed:
          ((map['reviewed'] as bool?) ?? false) ||
          ((map['session_reviews'] as List?)?.isNotEmpty ?? false),
    );
  }

  AnalysisStatus _mapAnalysisStatus(String? status) {
    return switch (status) {
      'ready' => AnalysisStatus.ready,
      'pending' => AnalysisStatus.pending,
      'incomplete' => AnalysisStatus.incomplete,
      'failed' => AnalysisStatus.failed,
      _ => AnalysisStatus.pending,
    };
  }

  String? _stringValue(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
