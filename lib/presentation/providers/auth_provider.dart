import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    onUnauthorized: () {
      ref.read(authProvider.notifier).clearSession();
    },
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthRepository(apiClient);
});

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? errorMessage;

  AuthState({this.user, this.isLoading = false, this.errorMessage});

  AuthState copyWith({UserModel? user, bool? isLoading, String? errorMessage}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  int _operation = 0;

  AuthNotifier(this._authRepository) : super(AuthState());

  Future<bool> login(String email, String password) async {
    final operation = ++_operation;
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final user = await _authRepository.login(email, password);
      if (!mounted || operation != _operation) return false;
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } catch (e) {
      if (!mounted || operation != _operation) return false;
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    clearSession();
    await _authRepository.logout();
  }

  void clearSession() {
    _operation++;
    state = AuthState();
  }

  Future<void> checkAuthStatus() async {
    final operation = ++_operation;
    state = state.copyWith(isLoading: true);
    try {
      final isLoggedIn = await _authRepository.isLoggedIn();
      if (!mounted || operation != _operation) return;
      if (!isLoggedIn) {
        state = AuthState();
        return;
      }
      final user = await _authRepository.getProfile();
      if (!mounted || operation != _operation) return;
      state = AuthState(user: user);
    } on DioException catch (e) {
      if (!mounted || operation != _operation) return;
      if (e.response?.statusCode == 401) {
        clearSession();
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              'Unable to verify your session. Check your connection and try again.',
        );
      }
    } catch (_) {
      if (!mounted || operation != _operation) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to verify your session. Please try again.',
      );
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthNotifier(authRepository);
});
