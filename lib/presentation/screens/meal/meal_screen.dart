import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/meal_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meal_provider.dart';
import 'meal_form_screen.dart';

const mealActionLabels = {
  'receive': 'Receive Originals',
  'verify': 'Verify',
  'approve': 'Approve',
  'pay': 'Mark Paid',
  'return': 'Return for Correction',
  'reject': 'Reject',
  'cancel': 'Cancel Claim',
};

class MealScreen extends ConsumerStatefulWidget {
  const MealScreen({super.key});
  @override
  ConsumerState<MealScreen> createState() => _MealScreenState();
}

class _MealScreenState extends ConsumerState<MealScreen> {
  bool _review = false;
  String _search = '';
  String? _status;
  StateNotifierProvider<MealNotifier, MealState> get _provider =>
      _review ? mealApprovalProvider : mealProvider;
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(_provider.notifier).load());
  }

  Future<void> _edit([MealModel? record]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MealFormScreen(record: record)),
    );
    if (mounted && saved == true) await ref.read(_provider.notifier).load();
  }

  Future<void> _act(MealModel record, String action) async {
    final note = TextEditingController();
    final form = GlobalKey<FormState>();
    final needsNote = ['return', 'reject'].contains(action);
    final hasNote = ['verify', 'pay', 'return', 'reject'].contains(action);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${mealActionLabels[action]} — Meal Claim #${record.id}'),
        scrollable: true,
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Employee: ${record.text('created_by')}\nTotal: IDR ${record.text('total_amount')}',
              ),
              const SizedBox(height: 12),
              Text(
                action == 'receive'
                    ? 'Confirm that the original physical receipts have been received.'
                    : action == 'pay'
                    ? 'Confirm that payment has been completed.'
                    : 'Confirm this action for the selected claim.',
              ),
              if (hasNote)
                TextFormField(
                  controller: note,
                  maxLength: 5000,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: needsNote
                        ? 'Reason (Required)'
                        : 'Note / Reference (Optional)',
                  ),
                  validator: (v) => needsNote && (v ?? '').trim().isEmpty
                      ? 'Enter a reason.'
                      : null,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: Text(mealActionLabels[action]!),
          ),
        ],
      ),
    );
    final value = note.text.trim();
    // Dispose after the closing dialog transition has released its text field.
    Future.delayed(const Duration(seconds: 1), note.dispose);
    if (!mounted || confirmed != true) return;
    final notifier = ref.read(_provider.notifier);
    final ok = await notifier.act(
      record.id,
      action,
      note: hasNote ? value : null,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Meal claim updated successfully.'
              : ref.read(_provider).submitError ?? 'Unable to update claim.',
        ),
      ),
    );
    if (ok) await notifier.load();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final canReview =
        user != null && (user.isAdmin || user.isSuperadmin || user.isSuperuser);
    final state = ref.watch(_provider);
    final rows = state.records
        .where(
          (r) =>
              (_status == null || r.text('status') == _status) &&
              '${r.id} ${r.text('created_by')} ${r.text('company_name')} ${r.text('employee_note')}'
                  .toLowerCase()
                  .contains(_search.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Meal Claims')),
      floatingActionButton: _review
          ? null
          : FloatingActionButton(
              onPressed: state.isSubmitting ? null : () => _edit(),
              tooltip: 'New Meal Claim',
              child: const Icon(Icons.add),
            ),
      body: Column(
        children: [
          if (canReview)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('My Claims')),
                  ButtonSegment(value: true, label: Text('Review Claims')),
                ],
                selected: {_review},
                onSelectionChanged: state.isSubmitting
                    ? null
                    : (v) {
                        setState(() {
                          _review = v.first;
                          _search = '';
                          _status = null;
                        });
                        ref.read(_provider.notifier).load();
                      },
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              key: ValueKey(_review),
              decoration: const InputDecoration(
                labelText: 'Search Claims',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              key: ValueKey('status-$_review'),
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('All Statuses'),
                ),
                ...[
                  'Submitted',
                  'Receipt Received',
                  'Verified',
                  'Approved',
                  'Paid',
                  'Returned',
                  'Rejected',
                  'Cancelled',
                ].map((s) => DropdownMenuItem(value: s, child: Text(s))),
              ],
              onChanged: (v) => setState(() => _status = v),
            ),
          ),
          if (state.isLoading || state.isSubmitting)
            const LinearProgressIndicator(),
          if (state.loadError != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(state.loadError!),
                  TextButton(
                    onPressed: () => ref.read(_provider.notifier).load(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(_provider.notifier).load(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (rows.isEmpty && !state.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No meal claims found.'),
                    ),
                  for (final r in rows)
                    Card(
                      child: ExpansionTile(
                        key: ValueKey(r.id),
                        title: Text(
                          'Meal Claim #${r.id} · ${r.text('status')}',
                        ),
                        subtitle: Text(
                          '${r.text('created_by')}\n${r.text('claim_date')} · IDR ${r.text('total_amount')}',
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Company: ${r.text('company_name')}\nReceipts: ${r.text('receipt_count')}',
                                ),
                                for (final entry in {
                                  'employee_note': 'Employee Note',
                                  'verification_note': 'Verification Note',
                                  'payment_note': 'Payment Reference',
                                  'rejected_note': 'Rejection Reason',
                                }.entries)
                                  if (r.text(entry.key).isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        '${entry.value}: ${r.text(entry.key)}',
                                      ),
                                    ),
                                for (final item in r.items)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      '${item['meal_type']} · IDR ${item['amount']}',
                                    ),
                                    subtitle: Text(
                                      '${item['meal_date']} · ${item['merchant'] ?? ''}\n${item['note'] ?? ''}',
                                    ),
                                    trailing: IconButton(
                                      tooltip: 'View Receipt',
                                      icon: const Icon(Icons.receipt_long),
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => _ReceiptScreen(
                                            claim: r.id,
                                            item: (item['id'] as num).toInt(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    if (r.canEdit)
                                      OutlinedButton(
                                        onPressed: state.isSubmitting
                                            ? null
                                            : () => _edit(r),
                                        child: const Text('Edit'),
                                      ),
                                    for (final action in r.actions)
                                      OutlinedButton(
                                        onPressed: state.isSubmitting
                                            ? null
                                            : () => _act(r, action),
                                        child: Text(
                                          mealActionLabels[action] ?? action,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final _receiptProvider = FutureProvider.autoDispose
    .family<List<int>, (int, int)>((ref, key) {
      ref.watch(authProvider.select((s) => s.user));
      return ref.watch(mealRepositoryProvider).receipt(key.$1, key.$2);
    });

class _ReceiptScreen extends ConsumerWidget {
  final int claim, item;
  const _ReceiptScreen({required this.claim, required this.item});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Receipt Photo')),
    body: ref
        .watch(_receiptProvider((claim, item)))
        .when(
          data: (bytes) => InteractiveViewer(
            child: Center(child: Image.memory(Uint8List.fromList(bytes))),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(_receiptProvider((claim, item))),
              child: const Text('Unable to load receipt. Retry'),
            ),
          ),
        ),
  );
}
