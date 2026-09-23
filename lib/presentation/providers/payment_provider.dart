import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/payment_model.dart';
import '../../data/repositories/payment_repository.dart';
import 'auth_provider.dart';

final paymentCompaniesProvider =
    FutureProvider.autoDispose<List<PaymentCompany>>((ref) {
      ref.watch(authProvider.select((state) => state.user));
      return ref.watch(paymentRepositoryProvider).getCompanies();
    });

final paymentRepositoryProvider = Provider(
  (ref) => PaymentRepository(ref.watch(apiClientProvider)),
);

class PaymentState {
  final List<PaymentModel> records;
  final bool isLoading;
  final bool isSubmitting;
  final String? loadError;
  final String? submitError;
  const PaymentState({
    this.records = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.loadError,
    this.submitError,
  });
}

class PaymentNotifier extends StateNotifier<PaymentState> {
  final PaymentRepository repository;
  final bool approvals;
  int _revision = 0;
  PaymentNotifier(this.repository, {this.approvals = false})
    : super(const PaymentState());

  Future<void> load() async {
    if (!mounted || state.isSubmitting) return;
    final revision = ++_revision;
    state = PaymentState(records: state.records, isLoading: true);
    try {
      final records = await repository.getList(approvals: approvals);
      if (!mounted || revision != _revision) return;
      state = PaymentState(records: records);
    } catch (e) {
      if (!mounted || revision != _revision) return;
      state = PaymentState(records: state.records, loadError: e.toString());
    }
  }

  Future<bool> create(PaymentDraft draft) =>
      _submit(() => repository.create(draft));
  Future<bool> cancel(int id) => _submit(() => repository.cancel(id));
  Future<bool> decide(int id, {String? rejectionReason}) =>
      _submit(() => repository.decide(id, rejectionReason: rejectionReason));

  Future<bool> _submit(Future<PaymentModel> Function() action) async {
    if (!mounted || state.isSubmitting) return false;
    ++_revision;
    state = PaymentState(records: state.records, isSubmitting: true);
    try {
      final record = await action();
      if (!mounted) return false;
      state = PaymentState(
        records: [
          if (!approvals || record.canApprove) record,
          ...state.records.where((r) => r.id != record.id),
        ],
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = PaymentState(records: state.records, submitError: e.toString());
      return false;
    }
  }
}

final paymentProvider = StateNotifierProvider<PaymentNotifier, PaymentState>((
  ref,
) {
  ref.watch(authProvider.select((state) => state.user));
  return PaymentNotifier(ref.watch(paymentRepositoryProvider));
});

final paymentApprovalProvider =
    StateNotifierProvider<PaymentNotifier, PaymentState>((ref) {
      ref.watch(authProvider.select((state) => state.user));
      return PaymentNotifier(
        ref.watch(paymentRepositoryProvider),
        approvals: true,
      );
    });
