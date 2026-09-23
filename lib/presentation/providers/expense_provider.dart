import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/expense_model.dart';
import '../../data/repositories/expense_repository.dart';
import 'auth_provider.dart';

final expenseCompaniesProvider =
    FutureProvider.autoDispose<List<ExpenseCompany>>((ref) {
      ref.watch(authProvider.select((state) => state.user));
      return ref.watch(expenseRepositoryProvider).getCompanies();
    });

final expenseRepositoryProvider = Provider(
  (ref) => ExpenseRepository(ref.watch(apiClientProvider)),
);

class ExpenseState {
  final List<ExpenseModel> records;
  final bool isLoading;
  final bool isSubmitting;
  final String? loadError;
  final String? submitError;
  const ExpenseState({
    this.records = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.loadError,
    this.submitError,
  });
}

class ExpenseNotifier extends StateNotifier<ExpenseState> {
  final ExpenseRepository repository;
  final bool approvals;
  int _revision = 0;
  ExpenseNotifier(this.repository, {this.approvals = false})
    : super(const ExpenseState());

  Future<void> load() async {
    if (!mounted || state.isSubmitting) return;
    final revision = ++_revision;
    state = ExpenseState(records: state.records, isLoading: true);
    try {
      final records = await repository.getList(approvals: approvals);
      if (!mounted || revision != _revision) return;
      state = ExpenseState(records: records);
    } catch (e) {
      if (!mounted || revision != _revision) return;
      state = ExpenseState(records: state.records, loadError: e.toString());
    }
  }

  Future<bool> save(ExpenseDraft draft, {int? id}) =>
      _submit(() => repository.save(draft, id: id));
  Future<bool> cancel(int id) => _submit(() => repository.cancel(id));
  Future<bool> decide(int id, {String? rejectionReason}) =>
      _submit(() => repository.decide(id, rejectionReason: rejectionReason));

  Future<bool> _submit(Future<ExpenseModel> Function() action) async {
    if (!mounted || state.isSubmitting) return false;
    ++_revision;
    state = ExpenseState(records: state.records, isSubmitting: true);
    try {
      final record = await action();
      if (!mounted) return false;
      state = ExpenseState(
        records: [
          if (!approvals || record.canApprove) record,
          ...state.records.where((r) => r.id != record.id),
        ],
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = ExpenseState(records: state.records, submitError: e.toString());
      return false;
    }
  }
}

final expenseProvider = StateNotifierProvider<ExpenseNotifier, ExpenseState>((
  ref,
) {
  ref.watch(authProvider.select((state) => state.user));
  return ExpenseNotifier(ref.watch(expenseRepositoryProvider));
});

final expenseApprovalProvider =
    StateNotifierProvider<ExpenseNotifier, ExpenseState>((ref) {
      ref.watch(authProvider.select((state) => state.user));
      return ExpenseNotifier(
        ref.watch(expenseRepositoryProvider),
        approvals: true,
      );
    });
