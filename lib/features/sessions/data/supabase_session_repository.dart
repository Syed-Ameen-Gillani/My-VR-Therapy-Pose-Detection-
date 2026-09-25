import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/therapy_session.dart';

class SupabaseSessionRepository implements SessionRepository {
  SupabaseSessionRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<void> createSession(
    TherapySession session, {
    required Map<String, Object?> payload,
    required String planId,
    required int planVersion,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppFailure('Sign in to save this session.');
    try {
      // A stable client-generated ID makes retry after a lost response safe.
      await _client
          .from('sessions')
          .upsert(
            {
              'id': session.id,
              'patient_id': session.patientId,
              'therapist_id': user.id,
              'exercise_id': session.exerciseId,
              'plan_id': planId,
              'plan_version': planVersion,
              'started_at': session.startedAt.toUtc().toIso8601String(),
              'duration_minutes': session.durationMinutes,
              'repetitions': session.repetitions,
              'analysis_status': session.analysis.name,
              'range_degrees': session.rangeDegrees,
              'analysis_payload': payload,
            },
            onConflict: 'id',
            ignoreDuplicates: true,
          );
    } catch (e) {
      throw AppFailure(
        'Session not saved. You can retry without duplicating it. $e',
      );
    }
  }

  @override
  Future<List<TherapySession>> getSessions() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const AppFailure('Authentication required to view sessions.');
      }

      final data = await _client
          .from('sessions')
          .select('*, session_reviews!left(therapist_id, therapist_note)')
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
        // Existing Supabase projects use therapist_note for this field.
        'therapist_note': note.trim(),
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
      reviewNote: _reviewNote(map['session_reviews']),
      analysisPayload: analysisPayload,
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

  String? _reviewNote(Object? value) {
    if (value is! List || value.isEmpty || value.first is! Map) return null;
    final row = Map<String, dynamic>.from(value.first as Map);
    return _stringValue(row['therapist_note'] ?? row['note']);
  }
}
