import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/register_letter_model.dart';
import '../../data/repositories/register_letter_repository.dart';
import 'auth_provider.dart';

final registerLetterCompaniesProvider =
    FutureProvider.autoDispose<List<RegisterLetterCompany>>((ref) {
      ref.watch(authProvider.select((state) => state.user));
      return ref.watch(registerLetterRepositoryProvider).getCompanies();
    });

final registerLetterRepositoryProvider = Provider(
  (ref) => RegisterLetterRepository(ref.watch(apiClientProvider)),
);

class RegisterLetterState {
  final List<RegisterLetterModel> records;
  final bool isLoading;
  final bool isSubmitting;
  final String? loadError;
  final String? submitError;
  const RegisterLetterState({
    this.records = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.loadError,
    this.submitError,
  });
}

class RegisterLetterNotifier extends StateNotifier<RegisterLetterState> {
  final RegisterLetterRepository repository;
  int _revision = 0;
  RegisterLetterNotifier(this.repository) : super(const RegisterLetterState());

  Future<void> load() async {
    if (!mounted || state.isSubmitting) return;
    final revision = ++_revision;
    state = RegisterLetterState(records: state.records, isLoading: true);
    try {
      final records = await repository.getList();
      if (!mounted || revision != _revision) return;
      state = RegisterLetterState(records: records);
    } catch (e) {
      if (!mounted || revision != _revision) return;
      state = RegisterLetterState(
        records: state.records,
        loadError: e.toString(),
      );
    }
  }

  Future<bool> save(RegisterLetterDraft draft, {int? id}) =>
      _submit(() => repository.save(draft, id: id));
  Future<bool> delete(int id) async {
    if (!mounted || state.isSubmitting) return false;
    ++_revision;
    state = RegisterLetterState(records: state.records, isSubmitting: true);
    try {
      await repository.delete(id);
      if (!mounted) return false;
      state = RegisterLetterState(
        records: state.records.where((r) => r.id != id).toList(),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = RegisterLetterState(
        records: state.records,
        submitError: e.toString(),
      );
      return false;
    }
  }

  Future<bool> _submit(Future<RegisterLetterModel> Function() action) async {
    if (!mounted || state.isSubmitting) return false;
    ++_revision;
    state = RegisterLetterState(records: state.records, isSubmitting: true);
    try {
      final record = await action();
      if (!mounted) return false;
      state = RegisterLetterState(
        records: [record, ...state.records.where((r) => r.id != record.id)],
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = RegisterLetterState(
        records: state.records,
        submitError: e.toString(),
      );
      return false;
    }
  }
}

final registerLetterProvider =
    StateNotifierProvider<RegisterLetterNotifier, RegisterLetterState>((ref) {
      ref.watch(authProvider.select((state) => state.user));
      return RegisterLetterNotifier(
        ref.watch(registerLetterRepositoryProvider),
      );
    });
