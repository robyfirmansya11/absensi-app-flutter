import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/cuti_model.dart';
import '../../data/repositories/cuti_repository.dart';
import 'auth_provider.dart';

final cutiRepositoryProvider = Provider<CutiRepository>((ref) {
  return CutiRepository(ref.watch(apiClientProvider));
});

class CutiState {
  final List<CutiModel> list;
  final KuotaCutiModel? quota;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;

  CutiState({
    this.list = const [],
    this.quota,
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
  });

  CutiState copyWith({
    List<CutiModel>? list,
    KuotaCutiModel? quota,
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
  }) {
    return CutiState(
      list: list ?? this.list,
      quota: quota ?? this.quota,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
    );
  }
}

class CutiNotifier extends StateNotifier<CutiState> {
  final CutiRepository _repo;

  CutiNotifier(this._repo) : super(CutiState());

  Future<void> loadAll() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final results = await Future.wait([_repo.getList(), _repo.getQuota()]);
      if (!mounted) return;
      state = state.copyWith(
        list: results[0] as List<CutiModel>,
        quota: results[1] as KuotaCutiModel,
        isLoading: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> create({
    required String jenisCuti,
    required String tanggalMulai,
    required String tanggalSelesai,
    required String alasan,
    PlatformFile? lampiran, // ← tambah ini
  }) async {
    if (!mounted) return false;
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      await _repo.create(
        jenisCuti: jenisCuti,
        tanggalMulai: tanggalMulai,
        tanggalSelesai: tanggalSelesai,
        alasan: alasan,
        lampiran: lampiran, // ← tambah ini
      );
      if (!mounted) return false;
      await loadAll();
      if (!mounted) return false;
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> cancel(int id) async {
    if (!mounted) return false;
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      await _repo.cancel(id);
      if (!mounted) return false;
      await loadAll();
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

final cutiProvider = StateNotifierProvider<CutiNotifier, CutiState>((ref) {
  ref.watch(authProvider.select((state) => state.user));
  return CutiNotifier(ref.watch(cutiRepositoryProvider));
});
