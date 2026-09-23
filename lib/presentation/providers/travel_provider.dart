import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/travel_model.dart';
import '../../data/repositories/travel_repository.dart';
import 'auth_provider.dart';

final travelCompaniesProvider = FutureProvider.autoDispose<List<TravelCompany>>(
  (ref) {
    ref.watch(authProvider.select((state) => state.user));
    return ref.watch(travelRepositoryProvider).getCompanies();
  },
);

final travelRepositoryProvider = Provider(
  (ref) => TravelRepository(ref.watch(apiClientProvider)),
);

class TravelState {
  final List<TravelModel> records;
  final bool isLoading;
  final bool isSubmitting;
  final String? loadError;
  final String? submitError;
  const TravelState({
    this.records = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.loadError,
    this.submitError,
  });
}

class TravelNotifier extends StateNotifier<TravelState> {
  final TravelRepository repository;
  final bool approvals;
  int _revision = 0;
  TravelNotifier(this.repository, {this.approvals = false})
    : super(const TravelState());

  Future<void> load() async {
    if (!mounted || state.isSubmitting) return;
    final revision = ++_revision;
    state = TravelState(records: state.records, isLoading: true);
    try {
      final records = await repository.getList(approvals: approvals);
      if (!mounted || revision != _revision) return;
      state = TravelState(records: records);
    } catch (e) {
      if (!mounted || revision != _revision) return;
      state = TravelState(records: state.records, loadError: e.toString());
    }
  }

  Future<bool> save(TravelDraft draft, {int? id}) =>
      _submit(() => repository.save(draft, id: id));
  Future<bool> cancel(int id) => _submit(() => repository.cancel(id));
  Future<bool> decide(int id, {String? rejectionReason}) =>
      _submit(() => repository.decide(id, rejectionReason: rejectionReason));

  Future<bool> _submit(Future<TravelModel> Function() action) async {
    if (!mounted || state.isSubmitting) return false;
    ++_revision;
    state = TravelState(records: state.records, isSubmitting: true);
    try {
      final record = await action();
      if (!mounted) return false;
      state = TravelState(
        records: [
          if (!approvals || record.canApprove) record,
          ...state.records.where((r) => r.id != record.id),
        ],
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = TravelState(records: state.records, submitError: e.toString());
      return false;
    }
  }
}

final travelProvider = StateNotifierProvider<TravelNotifier, TravelState>((
  ref,
) {
  ref.watch(authProvider.select((state) => state.user));
  return TravelNotifier(ref.watch(travelRepositoryProvider));
});

final travelApprovalProvider =
    StateNotifierProvider<TravelNotifier, TravelState>((ref) {
      ref.watch(authProvider.select((state) => state.user));
      return TravelNotifier(
        ref.watch(travelRepositoryProvider),
        approvals: true,
      );
    });
