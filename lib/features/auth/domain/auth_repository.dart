class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.displayName,
    this.role = 'therapist',
  });

  final String id;
  final String email;
  final String? displayName;
  final String role;
}

abstract interface class AuthRepository {
  Stream<AppUser?> get authStateChanges;
  AppUser? get currentUser;
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  });
  Future<void> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  });
  Future<void> signOut();
}
