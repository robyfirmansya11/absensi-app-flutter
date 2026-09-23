import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/expense_model.dart';
import '../../providers/expense_provider.dart';
import '../../providers/auth_provider.dart';
import 'expense_form_screen.dart';

class ExpenseScreen extends ConsumerStatefulWidget {
  const ExpenseScreen({super.key});
  @override
  ConsumerState<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends ConsumerState<ExpenseScreen> {
  String _search = '';
  bool _approvals = false;
  StateNotifierProvider<ExpenseNotifier, ExpenseState> get _provider =>
      _approvals ? expenseApprovalProvider : expenseProvider;
  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _approvals =
        user?.isSuperuser == true || user?.jabatan == 'Finance Manager';
    Future.microtask(() {
      if (mounted) ref.read(_provider.notifier).load();
    });
  }

  Future<void> _edit([ExpenseModel? record]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ExpenseFormScreen(record: record)),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Expense reimbursement saved successfully.'),
      ),
    );
    await ref.read(_provider.notifier).load();
  }

  Future<void> _cancel(ExpenseModel record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this request?'),
        content: Text('Expense reimbursement #${record.id} will be cancelled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final success = await ref.read(_provider.notifier).cancel(record.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Request cancelled.'
              : ref.read(_provider).submitError ??
                    'Unable to cancel the request.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_provider);
    final user = ref.watch(authProvider).user;
    final canReview =
        user?.isSuperuser == true || user?.jabatan == 'Finance Manager';
    final records = state.records
        .where(
          (r) => [
            'jumlah_total',
            'informasi_transfer',
            'company_name',
            'created_by',
            'keterangan',
          ].any((key) => r.text(key).toLowerCase().contains(_search)),
        )
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Expense Reimbursement Note'),
        bottom: canReview
            ? PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('My Requests')),
                      ButtonSegment(
                        value: true,
                        label: Text('Pending Approvals'),
                      ),
                    ],
                    selected: {_approvals},
                    onSelectionChanged: state.isSubmitting
                        ? null
                        : (values) {
                            setState(() {
                              _approvals = values.single;
                              _search = '';
                            });
                            ref.read(_provider.notifier).load();
                          },
                  ),
                ),
              )
            : null,
        actions: [
          IconButton(
            tooltip: 'New expense reimbursement',
            onPressed: state.isSubmitting ? null : () => _edit(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(_provider.notifier).load(),
              child: ListView(
                padding: const EdgeInsets.all(20),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (!canReview) const Text('My Requests'),
                  const SizedBox(height: 12),
                  TextField(
                    key: ValueKey(_approvals),
                    decoration: const InputDecoration(
                      labelText:
                          'Search by employee, amount, company, or description',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) =>
                        setState(() => _search = value.trim().toLowerCase()),
                  ),
                  const SizedBox(height: 16),
                  if (state.loadError != null) ...[
                    Text(state.loadError!),
                    TextButton(
                      onPressed: () => ref.read(_provider.notifier).load(),
                      child: const Text('Try Again'),
                    ),
                  ] else if (records.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _search.isEmpty
                            ? (_approvals
                                  ? 'No requests awaiting your approval.'
                                  : 'No expense reimbursements yet.')
                            : 'No matching expense reimbursements found.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (final record in records)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SelectableText(
                              'Reimbursement #${record.id}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Amount: ${NumberFormat.currency(locale: "en_US", symbol: "Rp ", decimalDigits: 2).format(double.tryParse(record.text('jumlah_total')) ?? 0)}',
                            ),
                            Text(
                              'Amount in Words: ${record.text('terbilang')}',
                            ),
                            if (record.text('informasi_transfer').isNotEmpty)
                              Text(
                                'Transfer Information: ${record.text('informasi_transfer')}',
                              ),
                            Text('Date: ${record.text('tanggal')}'),
                            Text(
                              'Attachment Count: ${record.text('jumlah_lampiran')}',
                            ),
                            ExpansionTile(
                              title: const Text('Expense Details'),
                              children: [
                                for (final d in record.details)
                                  ListTile(
                                    title: Text(
                                      d['keterangan']?.toString() ?? '',
                                    ),
                                    subtitle: Text('Rp ${d['jumlah']}'),
                                  ),
                              ],
                            ),
                            Text('Company: ${record.text('company_name')}'),
                            Text('Created By: ${record.text('created_by')}'),
                            if (record.text('keterangan').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(record.text('keterangan')),
                              ),
                            Text('Status: ${record.statusLabel}'),
                            if (record.text('rejected_note').isNotEmpty)
                              Text(
                                'Rejection Reason: ${record.text('rejected_note')}',
                              ),
                            if (record.hasAttachment)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text('Attachment saved'),
                              ),
                            Wrap(
                              spacing: 12,
                              children: [
                                if (_approvals && record.canApprove) ...[
                                  FilledButton.icon(
                                    onPressed: state.isSubmitting
                                        ? null
                                        : () => _decide(record, false),
                                    icon: const Icon(Icons.check),
                                    label: const Text('Approve'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: state.isSubmitting
                                        ? null
                                        : () => _decide(record, true),
                                    icon: const Icon(Icons.close),
                                    label: const Text('Reject'),
                                  ),
                                ],
                                if (!_approvals && record.canEdit)
                                  TextButton.icon(
                                    onPressed: state.isSubmitting
                                        ? null
                                        : () => _edit(record),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Edit'),
                                  ),
                                if (!_approvals && record.canCancel)
                                  TextButton.icon(
                                    onPressed: state.isSubmitting
                                        ? null
                                        : () => _cancel(record),
                                    icon: const Icon(Icons.cancel_outlined),
                                    label: const Text('Cancel'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Future<void> _decide(ExpenseModel record, bool reject) async {
    var reason = '';
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          reject
              ? 'Reject Expense Reimbursement Note'
              : 'Approve Expense Reimbursement Note',
        ),
        scrollable: true,
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${record.text('created_by')}\nExpense #${record.id}\nAmount: Rp ${record.text('jumlah_total')}',
              ),
              const SizedBox(height: 12),
              Text(record.text('keterangan')),
              if (!reject)
                Text(
                  record.data['approval_level'] == 1
                      ? 'This request will proceed according to the Finance Manager approval workflow.'
                      : 'This will complete the approval process.',
                ),
              if (reject)
                TextFormField(
                  onChanged: (value) => reason = value.trim(),
                  decoration: const InputDecoration(
                    labelText: 'Reason for Rejection',
                  ),
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 5000,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a reason for rejection.'
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
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: Text(reject ? 'Confirm Rejection' : 'Confirm Approval'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final notifier = ref.read(expenseApprovalProvider.notifier);
    final success = await notifier.decide(
      record.id,
      rejectionReason: reject ? reason : null,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (reject ? 'Request rejected.' : 'Request approved.')
              : ref.read(expenseApprovalProvider).submitError ??
                    'Unable to process this request.',
        ),
      ),
    );
    await notifier.load();
  }
}
