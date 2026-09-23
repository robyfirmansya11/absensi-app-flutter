import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/overtime_model.dart';
import '../../data/repositories/overtime_repository.dart';
import 'auth_provider.dart';

final overtimeRepositoryProvider = Provider(
  (ref) => OvertimeRepository(ref.watch(apiClientProvider)),
);

class OvertimeState {
  final List<OvertimeModel> records;
  final bool isLoading;
  final bool isSubmitting;
  final String? loadError;
  final String? submitError;
  const OvertimeState({
    this.records = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.loadError,
    this.submitError,
  });
}

class OvertimeNotifier extends StateNotifier<OvertimeState> {
  final OvertimeRepository repository;
  final bool approvals;
  int _revision = 0;
  OvertimeNotifier(this.repository, {this.approvals = false})
    : super(const OvertimeState());

  Future<void> load() async {
    if (!mounted || state.isSubmitting) return;
    final revision = ++_revision;
    state = OvertimeState(records: state.records, isLoading: true);
    try {
      final records = await repository.getList(approvals: approvals);
      if (!mounted || revision != _revision) return;
      state = OvertimeState(records: records);
    } catch (e) {
      if (!mounted || revision != _revision) return;
      state = OvertimeState(records: state.records, loadError: e.toString());
    }
  }

  Future<bool> create(OvertimeDraft draft) =>
      _submit(() => repository.create(draft));
  Future<bool> cancel(int id) => _submit(() => repository.cancel(id));
  Future<bool> decide(int id, {String? rejectionReason}) =>
      _submit(() => repository.decide(id, rejectionReason: rejectionReason));

  Future<bool> _submit(Future<OvertimeModel> Function() action) async {
    if (!mounted || state.isSubmitting) return false;
    ++_revision;
    state = OvertimeState(records: state.records, isSubmitting: true);
    try {
      final record = await action();
      if (!mounted) return false;
      state = OvertimeState(
        records: [
          if (!approvals || record.canApprove) record,
          ...state.records.where((r) => r.id != record.id),
        ],
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = OvertimeState(records: state.records, submitError: e.toString());
      return false;
    }
  }
}

final overtimeProvider = StateNotifierProvider<OvertimeNotifier, OvertimeState>(
  (ref) {
    ref.watch(authProvider.select((state) => state.user));
    return OvertimeNotifier(ref.watch(overtimeRepositoryProvider));
  },
);

final overtimeApprovalProvider =
    StateNotifierProvider<OvertimeNotifier, OvertimeState>((ref) {
      ref.watch(authProvider.select((state) => state.user));
      return OvertimeNotifier(
        ref.watch(overtimeRepositoryProvider),
        approvals: true,
      );
    });
