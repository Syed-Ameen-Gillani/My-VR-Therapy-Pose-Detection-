import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);
  final SupabaseClient _client;

  AppUser? _mapUser(User? user) {
    if (user == null) return null;
    return AppUser(
      id: user.id,
      email: user.email ?? '',
      displayName:
          user.userMetadata?['full_name'] as String? ??
          user.userMetadata?['name'] as String?,
      role: (user.userMetadata?['role'] as String?) ?? 'therapist',
    );
  }

  @override
  Stream<AppUser?> get authStateChanges => _client.auth.onAuthStateChange.map(
    (data) => _mapUser(data.session?.user),
  );

  @override
  AppUser? get currentUser => _mapUser(_client.auth.currentUser);

  @override
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      throw AppFailure(e.message);
    } catch (_) {
      throw const AppFailure(
        'Unable to sign in. Please check your connection.',
      );
    }
  }

  @override
  Future<void> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      await _client.auth.signUp(
        email: email,
        password: password,
        data: displayName != null ? {'full_name': displayName} : null,
      );
    } on AuthException catch (e) {
      throw AppFailure(e.message);
    } catch (_) {
      throw const AppFailure(
        'Unable to create account. Please check your connection.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (_) {
      throw const AppFailure('Failed to sign out. Please try again.');
    }
  }
}
