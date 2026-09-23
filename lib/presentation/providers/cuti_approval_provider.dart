import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/cuti_approval_model.dart';
import '../../data/repositories/cuti_approval_repository.dart';
import 'auth_provider.dart';

final cutiApprovalRepositoryProvider = Provider<CutiApprovalRepository>((ref) {
  return CutiApprovalRepository(ref.watch(apiClientProvider));
});

class CutiApprovalState {
  final List<CutiApprovalModel> list;
  final bool isLoading;
  final bool isProcessing;
  final String? errorMessage;

  CutiApprovalState({
    this.list = const [],
    this.isLoading = false,
    this.isProcessing = false,
    this.errorMessage,
  });

  CutiApprovalState copyWith({
    List<CutiApprovalModel>? list,
    bool? isLoading,
    bool? isProcessing,
    String? errorMessage,
  }) {
    return CutiApprovalState(
      list: list ?? this.list,
      isLoading: isLoading ?? this.isLoading,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: errorMessage,
    );
  }
}

class CutiApprovalNotifier extends StateNotifier<CutiApprovalState> {
  final CutiApprovalRepository _repo;
  int _revision = 0;

  CutiApprovalNotifier(this._repo) : super(CutiApprovalState());

  Future<void> loadAll() async {
    if (!mounted || state.isProcessing) return;
    final revision = ++_revision;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await _repo.getApprovalList();
      if (!mounted || revision != _revision) return;
      state = state.copyWith(list: list, isLoading: false);
    } catch (e) {
      if (!mounted || revision != _revision) return;
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> approve(int id) async {
    if (!mounted || state.isProcessing || state.isLoading) return false;
    ++_revision;
    state = state.copyWith(isProcessing: true, errorMessage: null);
    try {
      await _repo.approve(id);
      if (!mounted) return false;
      state = state.copyWith(
        list: state.list.where((item) => item.id != id).toList(),
        isProcessing: false,
      );
      await loadAll();
      if (!mounted) return false;
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(isProcessing: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> reject(int id, String note) async {
    if (!mounted || state.isProcessing || state.isLoading) return false;
    ++_revision;
    state = state.copyWith(isProcessing: true, errorMessage: null);
    try {
      await _repo.reject(id, note);
      if (!mounted) return false;
      state = state.copyWith(
        list: state.list.where((item) => item.id != id).toList(),
        isProcessing: false,
      );
      await loadAll();
      if (!mounted) return false;
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(isProcessing: false, errorMessage: e.toString());
      return false;
    }
  }
}

final cutiApprovalProvider =
    StateNotifierProvider<CutiApprovalNotifier, CutiApprovalState>((ref) {
      ref.watch(authProvider.select((state) => state.user));
      return CutiApprovalNotifier(ref.watch(cutiApprovalRepositoryProvider));
    });
