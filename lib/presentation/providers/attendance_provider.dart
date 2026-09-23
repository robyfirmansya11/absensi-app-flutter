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
  final String? historyErrorMessage;

  AttendanceState({
    this.today,
    this.history = const [],
    this.isLoading = false,
    this.isLoadingHistory = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.historyErrorMessage,
  });

  AttendanceState copyWith({
    AttendanceTodayModel? today,
    List<AttendanceHistoryModel>? history,
    bool? isLoading,
    bool? isLoadingHistory,
    bool? isSubmitting,
    String? errorMessage,
    String? historyErrorMessage,
    bool clearHistoryError = false,
  }) {
    return AttendanceState(
      today: today ?? this.today,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      historyErrorMessage: clearHistoryError
          ? null
          : historyErrorMessage ?? this.historyErrorMessage,
    );
  }
}

class AttendanceNotifier extends StateNotifier<AttendanceState> {
  final AttendanceRepository _repository;

  AttendanceNotifier(this._repository) : super(AttendanceState());

  /// Ambil status absensi hari ini — dipanggil saat halaman dibuka.
  Future<void> loadToday() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final today = await _repository.getToday();
      if (!mounted) return;
      state = state.copyWith(today: today, isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Load riwayat absensi.
  Future<void> loadHistory() async {
    if (!mounted) return;
    state = state.copyWith(isLoadingHistory: true, clearHistoryError: true);

    try {
      final history = await _repository.getHistory();
      if (!mounted) return;

      state = state.copyWith(history: history, isLoadingHistory: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoadingHistory: false,
        historyErrorMessage: e.toString(),
      );
    }
  }

  /// Proses clock-in. Return true kalau berhasil.
  Future<bool> clockIn({
    required double latitude,
    required double longitude,
    required File photo,
    String? address,
    String? reason,
    String? locationReason, // ← tambah
  }) async {
    if (!mounted) return false;
    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      await _repository.clockIn(
        latitude: latitude,
        longitude: longitude,
        photo: photo,
        address: address,
        reason: reason,
        locationReason: locationReason, // ← tambah
      );
      if (!mounted) return false;

      await loadToday();
      if (!mounted) return false;
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> clockOut({
    required double latitude,
    required double longitude,
    required File photo,
    String? address,
    String? reason,
    String? locationReason, // ← tambah
  }) async {
    if (!mounted) return false;
    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      await _repository.clockOut(
        latitude: latitude,
        longitude: longitude,
        photo: photo,
        address: address,
        reason: reason,
        locationReason: locationReason, // ← tambah
      );
      if (!mounted) return false;

      await loadToday();
      if (!mounted) return false;
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }
}

final attendanceProvider =
    StateNotifierProvider<AttendanceNotifier, AttendanceState>((ref) {
      ref.watch(authProvider.select((state) => state.user));
      final repository = ref.watch(attendanceRepositoryProvider);
      return AttendanceNotifier(repository);
    });
