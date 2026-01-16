import '../../../data/models/user.dart';

/// Simple auth state model for the login/register screens.
class AuthState {
  const AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.user,
  });

  final bool isLoading;
  final String? errorMessage;
  final User? user;

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    User? user,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      user: user ?? this.user,
    );
  }
}


