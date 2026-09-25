import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/patient.dart';

class SupabasePatientRepository implements PatientRepository {
  SupabasePatientRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<Patient>> getPatients() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const AppFailure('Authentication required to view patients.');
      }

      final data = await _client
          .from('patients')
          .select()
          .eq('therapist_id', user.id)
          .eq('archived', false)
          .order('name');

      return (data as List<dynamic>).map((row) {
        final map = row as Map<String, dynamic>;
        return Patient(
          id: map['id'] as String,
          name: map['name'] as String,
          goal: map['goal'] as String,
          initials: map['initials'] as String,
          archived: (map['archived'] as bool?) ?? false,
          activePlanId: map['active_plan_id'] as String?,
        );
      }).toList();
    } on AppFailure {
      rethrow;
    } catch (e) {
      throw AppFailure('Failed to load patients: $e');
    }
  }

  @override
  Future<Patient> createPatient({
    required String name,
    required String goal,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const AppFailure('Authentication required to create a patient.');
      }

      final parts = name.trim().split(RegExp(r'\s+'));
      final initials = parts
          .take(2)
          .map((s) => s.isNotEmpty ? s[0].toUpperCase() : '')
          .join();
      final id = 'p_${DateTime.now().millisecondsSinceEpoch}';

      final payload = {
        'id': id,
        'therapist_id': user.id,
        'name': name.trim(),
        'initials': initials.isEmpty ? 'PT' : initials,
        'goal': goal.trim(),
        'archived': false,
        'revision': 1,
      };

      await _client.from('patients').insert(payload);

      return Patient(
        id: id,
        name: name.trim(),
        goal: goal.trim(),
        initials: initials.isEmpty ? 'PT' : initials,
      );
    } on AppFailure {
      rethrow;
    } catch (e) {
      throw AppFailure('Failed to save patient: $e');
    }
  }

  @override
  Future<Patient> updatePatient({
    required String id,
    required String name,
    required String goal,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const AppFailure('Authentication required to update a patient.');
      }

      final initials = _initialsFor(name);
      final data = await _client
          .from('patients')
          .update({
            'name': name.trim(),
            'initials': initials,
            'goal': goal.trim(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id)
          .eq('therapist_id', user.id)
          .select()
          .single();

      final map = data;
      return Patient(
        id: map['id'] as String,
        name: map['name'] as String,
        goal: map['goal'] as String,
        initials: map['initials'] as String,
        archived: (map['archived'] as bool?) ?? false,
        activePlanId: map['active_plan_id'] as String?,
      );
    } on AppFailure {
      rethrow;
    } catch (e) {
      throw AppFailure('Failed to update patient: $e');
    }
  }

  @override
  Future<void> archivePatient(String id) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const AppFailure('Authentication required to archive a patient.');
      }

      await _client
          .from('patients')
          .update({
            'archived': true,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id)
          .eq('therapist_id', user.id);
    } on AppFailure {
      rethrow;
    } catch (e) {
      throw AppFailure('Failed to archive patient: $e');
    }
  }

  String _initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts
        .take(2)
        .map((s) => s.isNotEmpty ? s[0].toUpperCase() : '')
        .join();
    return initials.isEmpty ? 'PT' : initials;
  }
}
