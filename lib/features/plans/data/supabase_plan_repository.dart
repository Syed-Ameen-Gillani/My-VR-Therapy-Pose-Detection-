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

      try {
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
      } on PostgrestException catch (e) {
        // If the database RPC failed because of schema mismatch (such as missing updated_at),
        // fallback to direct table operations which do not depend on the missing column.
        if (e.code == '42703' ||
            e.message.toLowerCase().contains('updated_at')) {
          return await _savePlanDirect(
            userId: user.id,
            patientId: patientId,
            title: title.trim(),
            exerciseIds: exerciseIds,
            scheduledSessions: scheduledSessions,
          );
        }
        rethrow;
      }
    } on AppFailure {
      rethrow;
    } catch (e) {
      throw AppFailure('Failed to save prescription plan: $e');
    }
  }

  Future<RehabilitationPlan> _savePlanDirect({
    required String userId,
    required String patientId,
    required String title,
    required List<String> exerciseIds,
    required int scheduledSessions,
  }) async {
    final rows = await _client
        .from('plans')
        .select()
        .eq('therapist_id', userId)
        .eq('patient_id', patientId)
        .eq('status', 'active')
        .order('version', ascending: false)
        .limit(1);

    final existingRow = rows.isNotEmpty ? rows.first : null;

    final String planId;
    final int version;

    if (existingRow != null) {
      planId = existingRow['id'] as String;
      version = ((existingRow['version'] as int?) ?? 1) + 1;

      await _client.from('plans').update({
        'title': title,
        'exercise_ids': exerciseIds,
        'scheduled_sessions': scheduledSessions,
        'version': version,
      }).eq('id', planId).eq('therapist_id', userId);
    } else {
      planId = 'plan_${DateTime.now().millisecondsSinceEpoch}_${patientId.hashCode.abs()}';
      version = 1;

      await _client.from('plans').insert({
        'id': planId,
        'patient_id': patientId,
        'therapist_id': userId,
        'title': title,
        'exercise_ids': exerciseIds,
        'scheduled_sessions': scheduledSessions,
        'version': version,
        'status': 'active',
      });
    }

    await _client.from('plan_versions').insert({
      'plan_id': planId,
      'version': version,
      'title': title,
      'exercise_ids': exerciseIds,
      'scheduled_sessions': scheduledSessions,
    });

    await _client.from('patients').update({
      'active_plan_id': planId,
    }).eq('id', patientId).eq('therapist_id', userId);

    return RehabilitationPlan(
      id: planId,
      patientId: patientId,
      title: title,
      exerciseIds: exerciseIds,
      scheduledSessions: scheduledSessions,
      version: version,
      status: 'active',
    );
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
