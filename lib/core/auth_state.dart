import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'models/user.dart';

/// Auth state representing the authentication status
enum AuthStatus { initial, authenticated, unauthenticated }

/// Auth state class containing user and status
class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;

  const AuthState({this.status = AuthStatus.initial, this.user, this.error});

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;
  bool get isLoading => status == AuthStatus.initial;

  AuthState copyWith({AuthStatus? status, User? user, String? error}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error ?? this.error,
    );
  }
}

/// Auth state notifier for managing authentication state
class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier() : super(const AuthState()) {
    _init();
  }

  void _init() {
    // Listen to Firebase auth state changes
    firebase_auth.FirebaseAuth.instance.authStateChanges().listen((
      firebaseUser,
    ) {
      if (firebaseUser != null) {
        _setAuthenticatedUser(firebaseUser);
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    });
  }

  void _setAuthenticatedUser(firebase_auth.User firebaseUser) {
    final user = User(
      id: firebaseUser.uid,
      name: firebaseUser.displayName ?? 'Utilisateur',
      email: firebaseUser.email ?? '',
      avatarUrl: firebaseUser.photoURL,
      isOnline: true,
    );
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }

  /// Update user profile information
  void updateUserProfile({String? name, String? avatarUrl}) {
    if (state.user != null) {
      final updatedUser = state.user!.copyWith(
        name: name,
        avatarUrl: avatarUrl,
      );
      state = state.copyWith(user: updatedUser);
    }
  }

  /// Set user online status
  void setOnlineStatus(bool isOnline) {
    if (state.user != null) {
      final updatedUser = state.user!.copyWith(
        isOnline: isOnline,
        lastSeen: isOnline ? null : DateTime.now(),
      );
      state = state.copyWith(user: updatedUser);
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    try {
      await firebase_auth.FirebaseAuth.instance.signOut();
      state = const AuthState(status: AuthStatus.unauthenticated);
    } catch (e) {
      state = state.copyWith(error: 'Erreur lors de la déconnexion: $e');
    }
  }

  /// Clear any error message
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for auth state
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((
  ref,
) {
  return AuthStateNotifier();
});

/// Provider to check if user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).isAuthenticated;
});

/// Provider to get current user
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).user;
});
