import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/loan_model.dart';
import '../../data/repositories/loan_repository.dart';
import 'auth_provider.dart';

final loanCompaniesProvider = FutureProvider.autoDispose<List<LoanCompany>>((
  ref,
) {
  ref.watch(authProvider.select((state) => state.user));
  return ref.watch(loanRepositoryProvider).getCompanies();
});

final loanRepositoryProvider = Provider(
  (ref) => LoanRepository(ref.watch(apiClientProvider)),
);

class LoanState {
  final List<LoanModel> records;
  final bool isLoading;
  final bool isSubmitting;
  final String? loadError;
  final String? submitError;
  const LoanState({
    this.records = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.loadError,
    this.submitError,
  });
}

class LoanNotifier extends StateNotifier<LoanState> {
  final LoanRepository repository;
  final bool approvals;
  int _revision = 0;
  LoanNotifier(this.repository, {this.approvals = false})
    : super(const LoanState());

  Future<void> load() async {
    if (!mounted || state.isSubmitting) return;
    final revision = ++_revision;
    state = LoanState(records: state.records, isLoading: true);
    try {
      final records = await repository.getList(approvals: approvals);
      if (!mounted || revision != _revision) return;
      state = LoanState(records: records);
    } catch (e) {
      if (!mounted || revision != _revision) return;
      state = LoanState(records: state.records, loadError: e.toString());
    }
  }

  Future<bool> save(LoanDraft draft, {int? id}) =>
      _submit(() => repository.save(draft, id: id));
  Future<bool> cancel(int id) => _submit(() => repository.cancel(id));
  Future<bool> decide(int id, {String? rejectionReason}) =>
      _submit(() => repository.decide(id, rejectionReason: rejectionReason));

  Future<bool> _submit(Future<LoanModel> Function() action) async {
    if (!mounted || state.isSubmitting) return false;
    ++_revision;
    state = LoanState(records: state.records, isSubmitting: true);
    try {
      final record = await action();
      if (!mounted) return false;
      state = LoanState(
        records: [
          if (!approvals || record.canApprove) record,
          ...state.records.where((r) => r.id != record.id),
        ],
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = LoanState(records: state.records, submitError: e.toString());
      return false;
    }
  }
}

final loanProvider = StateNotifierProvider<LoanNotifier, LoanState>((ref) {
  ref.watch(authProvider.select((state) => state.user));
  return LoanNotifier(ref.watch(loanRepositoryProvider));
});

final loanApprovalProvider = StateNotifierProvider<LoanNotifier, LoanState>((
  ref,
) {
  ref.watch(authProvider.select((state) => state.user));
  return LoanNotifier(ref.watch(loanRepositoryProvider), approvals: true);
});
