class Patient {
  const Patient({
    required this.id,
    required this.name,
    required this.goal,
    required this.initials,
    this.archived = false,
    this.activePlanId,
  });
  final String id, name, goal, initials;
  final bool archived;
  final String? activePlanId;

  Patient copyWith({
    String? id,
    String? name,
    String? goal,
    String? initials,
    bool? archived,
    String? activePlanId,
  }) => Patient(
    id: id ?? this.id,
    name: name ?? this.name,
    goal: goal ?? this.goal,
    initials: initials ?? this.initials,
    archived: archived ?? this.archived,
    activePlanId: activePlanId ?? this.activePlanId,
  );
}

abstract interface class PatientRepository {
  Future<List<Patient>> getPatients();
  Future<Patient> createPatient({required String name, required String goal});
  Future<Patient> updatePatient({
    required String id,
    required String name,
    required String goal,
  });
  Future<void> archivePatient(String id);
}
