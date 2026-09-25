import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/exercise.dart';

class SupabaseExerciseRepository implements ExerciseRepository {
  SupabaseExerciseRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<Exercise>> getExercises() async {
    try {
      final data = await _client.from('exercises').select().order('name');
      return (data as List<dynamic>).map((row) {
        final map = row as Map<String, dynamic>;
        return Exercise(
          id: map['id'] as String,
          name: map['name'] as String,
          category: map['category'] as String,
          instructions: map['instructions'] as String,
          equipment: map['equipment'] as String,
        );
      }).toList();
    } catch (e) {
      throw AppFailure('Failed to load exercises: $e');
    }
  }
}
