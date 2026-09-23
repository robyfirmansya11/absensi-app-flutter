import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/stamp_model.dart';
import '../../data/repositories/stamp_repository.dart';
import 'auth_provider.dart';

final stampCompaniesProvider = FutureProvider.autoDispose<List<StampCompany>>((
  ref,
) {
  ref.watch(authProvider.select((state) => state.user));
  return ref.watch(stampRepositoryProvider).getCompanies();
});

final stampRepositoryProvider = Provider(
  (ref) => StampRepository(ref.watch(apiClientProvider)),
);

class StampState {
  final List<StampModel> records;
  final bool isLoading;
  final bool isSubmitting;
  final String? loadError;
  final String? submitError;
  const StampState({
    this.records = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.loadError,
    this.submitError,
  });
}

class StampNotifier extends StateNotifier<StampState> {
  final StampRepository repository;
  final bool approvals;
  int _revision = 0;
  StampNotifier(this.repository, {this.approvals = false})
    : super(const StampState());

  Future<void> load() async {
    if (!mounted || state.isSubmitting) return;
    final revision = ++_revision;
    state = StampState(records: state.records, isLoading: true);
    try {
      final records = await repository.getList(approvals: approvals);
      if (!mounted || revision != _revision) return;
      state = StampState(records: records);
    } catch (e) {
      if (!mounted || revision != _revision) return;
      state = StampState(records: state.records, loadError: e.toString());
    }
  }

  Future<bool> save(StampDraft draft, {int? id}) =>
      _submit(() => repository.save(draft, id: id));
  Future<bool> cancel(int id) => _submit(() => repository.cancel(id));
  Future<bool> decide(int id, {String? rejectionReason}) =>
      _submit(() => repository.decide(id, rejectionReason: rejectionReason));

  Future<bool> _submit(Future<StampModel> Function() action) async {
    if (!mounted || state.isSubmitting) return false;
    ++_revision;
    state = StampState(records: state.records, isSubmitting: true);
    try {
      final record = await action();
      if (!mounted) return false;
      state = StampState(
        records: [
          if (!approvals || record.canApprove) record,
          ...state.records.where((r) => r.id != record.id),
        ],
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = StampState(records: state.records, submitError: e.toString());
      return false;
    }
  }
}

final stampProvider = StateNotifierProvider<StampNotifier, StampState>((ref) {
  ref.watch(authProvider.select((state) => state.user));
  return StampNotifier(ref.watch(stampRepositoryProvider));
});

final stampApprovalProvider = StateNotifierProvider<StampNotifier, StampState>((
  ref,
) {
  ref.watch(authProvider.select((state) => state.user));
  return StampNotifier(ref.watch(stampRepositoryProvider), approvals: true);
});
