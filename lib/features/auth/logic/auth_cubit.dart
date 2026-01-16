import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/user.dart';
import '../../../data/repositories/auth_repository.dart';
import 'auth_state.dart';

/// Thin BLoC layer to keep auth logic testable and separate from UI.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    AuthRepository? repository,
  })  : _repository = repository ?? AuthRepository(),
        super(const AuthState());

  final AuthRepository _repository;

  Future<User?> register(String email, String password) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final user = await _repository.register(email: email, password: password);
      emit(AuthState(isLoading: false, user: user));
      return user;
    } on AuthException catch (e) {
      emit(AuthState(isLoading: false, errorMessage: e.message));
      return null;
    } catch (_) {
      emit(
        const AuthState(
          isLoading: false,
          errorMessage: 'Something went wrong. Please try again.',
        ),
      );
      return null;
    }
  }

  Future<User?> login(String email, String password) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final user = await _repository.login(email: email, password: password);
      emit(AuthState(isLoading: false, user: user));
      return user;
    } on AuthException catch (e) {
      emit(AuthState(isLoading: false, errorMessage: e.message));
      return null;
    } catch (_) {
      emit(
        const AuthState(
          isLoading: false,
          errorMessage: 'Something went wrong. Please try again.',
        ),
      );
      return null;
    }
  }
}


