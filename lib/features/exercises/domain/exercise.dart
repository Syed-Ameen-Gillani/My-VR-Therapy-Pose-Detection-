class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.category,
    required this.instructions,
    required this.equipment,
  });
  final String id, name, category, instructions, equipment;
}

abstract interface class ExerciseRepository {
  Future<List<Exercise>> getExercises();
}
