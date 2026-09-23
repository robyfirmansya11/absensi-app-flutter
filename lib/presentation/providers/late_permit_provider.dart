import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/late_permit_model.dart';
import '../../data/repositories/late_permit_repository.dart';
import 'auth_provider.dart';

final latePermitRepositoryProvider = Provider(
  (ref) => LatePermitRepository(ref.watch(apiClientProvider)),
);

class LatePermitState {
  final List<LatePermitModel> records;
  final bool isLoading;
  final bool isSubmitting;
  final String? loadError;
  final String? submitError;
  const LatePermitState({
    this.records = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.loadError,
    this.submitError,
  });
}

class LatePermitNotifier extends StateNotifier<LatePermitState> {
  final LatePermitRepository repository;
  final bool approvals;
  int _revision = 0;
  LatePermitNotifier(this.repository, {this.approvals = false})
    : super(const LatePermitState());

  Future<void> load() async {
    if (!mounted || state.isSubmitting) return;
    final revision = ++_revision;
    state = LatePermitState(records: state.records, isLoading: true);
    try {
      final records = await repository.getList(approvals: approvals);
      if (!mounted || revision != _revision) return;
      state = LatePermitState(records: records);
    } catch (e) {
      if (!mounted || revision != _revision) return;
      state = LatePermitState(records: state.records, loadError: e.toString());
    }
  }

  Future<bool> create(LatePermitDraft draft) =>
      _submit(() => repository.create(draft));
  Future<bool> cancel(int id) => _submit(() => repository.cancel(id));
  Future<bool> decide(int id, {String? rejectionReason}) =>
      _submit(() => repository.decide(id, rejectionReason: rejectionReason));

  Future<bool> _submit(Future<LatePermitModel> Function() action) async {
    if (!mounted || state.isSubmitting) return false;
    ++_revision;
    state = LatePermitState(records: state.records, isSubmitting: true);
    try {
      final record = await action();
      if (!mounted) return false;
      state = LatePermitState(
        records: [
          if (!approvals || record.canApprove) record,
          ...state.records.where((r) => r.id != record.id),
        ],
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = LatePermitState(
        records: state.records,
        submitError: e.toString(),
      );
      return false;
    }
  }
}

final latePermitProvider =
    StateNotifierProvider<LatePermitNotifier, LatePermitState>((ref) {
      ref.watch(authProvider.select((state) => state.user));
      return LatePermitNotifier(ref.watch(latePermitRepositoryProvider));
    });

final latePermitApprovalProvider =
    StateNotifierProvider<LatePermitNotifier, LatePermitState>((ref) {
      ref.watch(authProvider.select((state) => state.user));
      return LatePermitNotifier(
        ref.watch(latePermitRepositoryProvider),
        approvals: true,
      );
    });
