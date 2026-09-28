import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/meal_model.dart';
import '../../data/repositories/meal_repository.dart';
import 'auth_provider.dart';

final mealCompaniesProvider = FutureProvider.autoDispose<List<MealCompany>>((
  ref,
) {
  ref.watch(authProvider.select((state) => state.user));
  return ref.watch(mealRepositoryProvider).getCompanies();
});

final mealRepositoryProvider = Provider(
  (ref) => MealRepository(ref.watch(apiClientProvider)),
);

class MealState {
  final List<MealModel> records;
  final bool isLoading;
  final bool isSubmitting;
  final String? loadError;
  final String? submitError;
  const MealState({
    this.records = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.loadError,
    this.submitError,
  });
}

class MealNotifier extends StateNotifier<MealState> {
  final MealRepository repository;
  final bool approvals;
  int _revision = 0;
  MealNotifier(this.repository, {this.approvals = false})
    : super(const MealState());

  Future<void> load() async {
    if (!mounted || state.isSubmitting) return;
    final revision = ++_revision;
    state = MealState(records: state.records, isLoading: true);
    try {
      final records = await repository.getList(approvals: approvals);
      if (!mounted || revision != _revision) return;
      state = MealState(records: records);
    } catch (e) {
      if (!mounted || revision != _revision) return;
      state = MealState(records: state.records, loadError: e.toString());
    }
  }

  Future<bool> save(MealDraft draft, {int? id}) =>
      _submit(() => repository.save(draft, id: id));
  Future<bool> cancel(int id) => _submit(() => repository.cancel(id));
  Future<bool> act(int id, String action, {String? note}) =>
      _submit(() => repository.act(id, action, note: note));

  Future<bool> _submit(Future<MealModel> Function() action) async {
    if (!mounted || state.isSubmitting) return false;
    ++_revision;
    state = MealState(records: state.records, isSubmitting: true);
    try {
      final record = await action();
      if (!mounted) return false;
      state = MealState(
        records: [
          if (!approvals || record.canApprove) record,
          ...state.records.where((r) => r.id != record.id),
        ],
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = MealState(records: state.records, submitError: e.toString());
      return false;
    }
  }
}

final mealProvider = StateNotifierProvider<MealNotifier, MealState>((ref) {
  ref.watch(authProvider.select((state) => state.user));
  return MealNotifier(ref.watch(mealRepositoryProvider));
});

final mealApprovalProvider = StateNotifierProvider<MealNotifier, MealState>((
  ref,
) {
  ref.watch(authProvider.select((state) => state.user));
  return MealNotifier(ref.watch(mealRepositoryProvider), approvals: true);
});
