import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/attendance_model.dart';
import '../../data/repositories/attendance_repository.dart';
import 'auth_provider.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AttendanceRepository(apiClient);
});

/// State untuk halaman absensi hari ini.
class AttendanceState {
  final AttendanceTodayModel? today;

  final List<AttendanceHistoryModel> history;

  final bool isLoading;

  final bool isLoadingHistory;

  final bool isSubmitting;

  final String? errorMessage;

  AttendanceState({
    this.today,
    this.history = const [],
    this.isLoading = false,
    this.isLoadingHistory = false,
    this.isSubmitting = false,
    this.errorMessage,
  });

  AttendanceState copyWith({
    AttendanceTodayModel? today,
    List<AttendanceHistoryModel>? history,
    bool? isLoading,
    bool? isLoadingHistory,
    bool? isSubmitting,
    String? errorMessage,
  }) {
    return AttendanceState(
      today: today ?? this.today,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
    );
  }
}

class AttendanceNotifier extends StateNotifier<AttendanceState> {
  final AttendanceRepository _repository;

  AttendanceNotifier(this._repository) : super(AttendanceState());

  /// Ambil status absensi hari ini — dipanggil saat halaman dibuka.
  Future<void> loadToday() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final today = await _repository.getToday();
      state = state.copyWith(today: today, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Load riwayat absensi.
  Future<void> loadHistory() async {
    state = state.copyWith(isLoadingHistory: true, errorMessage: null);

    try {
      final history = await _repository.getHistory();

      state = state.copyWith(history: history, isLoadingHistory: false);
    } catch (e) {
      state = state.copyWith(
        isLoadingHistory: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Proses clock-in. Return true kalau berhasil.
  Future<bool> clockIn({
    required double latitude,
    required double longitude,
    required File photo,
    String? address,
  }) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      await _repository.clockIn(
        latitude: latitude,
        longitude: longitude,
        photo: photo,
        address: address,
      );

      // Refresh status hari ini setelah berhasil
      await loadToday();
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Proses clock-out. Return true kalau berhasil.
  Future<bool> clockOut({
    required double latitude,
    required double longitude,
    required File photo,
    String? address,
  }) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      await _repository.clockOut(
        latitude: latitude,
        longitude: longitude,
        photo: photo,
        address: address,
      );

      await loadToday();
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }
}

final attendanceProvider =
    StateNotifierProvider<AttendanceNotifier, AttendanceState>((ref) {
      final repository = ref.watch(attendanceRepositoryProvider);
      return AttendanceNotifier(repository);
    });
