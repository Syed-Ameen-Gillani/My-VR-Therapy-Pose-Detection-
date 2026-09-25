import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/rehabilitation_plan.dart';

class SupabasePlanRepository implements PlanRepository {
  SupabasePlanRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<RehabilitationPlan>> getPlans() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const AppFailure('Authentication required to view plans.');
      }

      final data = await _client
          .from('plans')
          .select()
          .eq('therapist_id', user.id)
          .eq('status', 'active');

      return (data as List<dynamic>).map((row) {
        final map = row as Map<String, dynamic>;
        return _mapRowToPlan(map);
      }).toList();
    } on AppFailure {
      rethrow;
    } catch (e) {
      throw AppFailure('Failed to load rehabilitation plans: $e');
    }
  }

  @override
  Future<RehabilitationPlan?> getPlanForPatient(String patientId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const AppFailure('Authentication required to view plan.');
      }

      final data = await _client
          .from('plans')
          .select()
          .eq('therapist_id', user.id)
          .eq('patient_id', patientId)
          .eq('status', 'active')
          .maybeSingle();

      if (data == null) return null;
      return _mapRowToPlan(data);
    } on AppFailure {
      rethrow;
    } catch (e) {
      throw AppFailure('Failed to load patient plan: $e');
    }
  }

  @override
  Future<RehabilitationPlan> savePlan({
    required String patientId,
    required String title,
    required List<String> exerciseIds,
    required int scheduledSessions,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const AppFailure('Authentication required to save plan.');
      }

      final data = await _client.rpc(
        'activate_plan',
        params: {
          'p_patient_id': patientId,
          'p_title': title.trim(),
          'p_exercise_ids': exerciseIds,
          'p_scheduled_sessions': scheduledSessions,
        },
      );

      final map = switch (data) {
        final List<dynamic> rows when rows.isNotEmpty =>
          rows.first as Map<String, dynamic>,
        final Map<String, dynamic> row => row,
        _ => throw const AppFailure(
          'Plan activation completed without returning a plan.',
        ),
      };
      return _mapRowToPlan(map);
    } on AppFailure {
      rethrow;
    } catch (e) {
      throw AppFailure('Failed to save prescription plan: $e');
    }
  }

  RehabilitationPlan _mapRowToPlan(Map<String, dynamic> map) {
    final rawIds = map['exercise_ids'];
    final exerciseIds = rawIds is List
        ? rawIds.map((e) => e.toString()).toList()
        : <String>[];

    return RehabilitationPlan(
      id: map['id'] as String?,
      patientId: map['patient_id'] as String,
      title: map['title'] as String,
      exerciseIds: exerciseIds,
      scheduledSessions: (map['scheduled_sessions'] as int?) ?? 1,
      version: (map['version'] as int?) ?? 1,
      status: (map['status'] as String?) ?? 'active',
    );
  }
}
