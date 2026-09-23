import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/payment_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/payment_provider.dart';
import 'create_payment_screen.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});
  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool _approvals = false;
  StateNotifierProvider<PaymentNotifier, PaymentState> get _provider =>
      _approvals ? paymentApprovalProvider : paymentProvider;
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

  Future<void> _create() async {
    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreatePaymentScreen()),
    );
    if (!mounted || success != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment application submitted successfully.'),
      ),
    );
    await ref.read(_provider.notifier).load();
  }

  Future<void> _cancel(PaymentModel record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this request?'),
        content: Text(
          'The payment application for invoice ${record.invoice} will be cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Request'),
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
              ? 'Payment application cancelled.'
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
    final canCreate = ref.watch(authProvider).user != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Payment Application Letter'),
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
                            setState(() => _approvals = values.single);
                            ref.read(_provider.notifier).load();
                          },
                  ),
                ),
              )
            : null,
        foregroundColor: const Color(0xFF1B4F8A),
        actions: [
          if (canCreate)
            IconButton(
              tooltip: 'New payment application',
              onPressed: state.isSubmitting ? null : _create,
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
                  if (!canReview)
                    const Text(
                      'My Requests',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  const SizedBox(height: 12),
                  if (state.loadError != null) ...[
                    Text(state.loadError!, textAlign: TextAlign.center),
                    TextButton(
                      onPressed: () => ref.read(_provider.notifier).load(),
                      child: const Text('Try Again'),
                    ),
                  ] else if (state.records.isEmpty) ...[
                    const SizedBox(height: 80),
                    const Icon(
                      Icons.request_quote_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _approvals
                          ? 'No requests awaiting your approval.'
                          : 'No payment applications yet.',
                      textAlign: TextAlign.center,
                    ),
                    if (canCreate && !_approvals)
                      TextButton(
                        onPressed: _create,
                        child: const Text('New Request'),
                      ),
                  ],
                  for (final record in state.records)
                    _card(record, state.isSubmitting),
                ],
              ),
            ),
    );
  }

  Widget _card(PaymentModel record, bool busy) {
    String money(String key) => NumberFormat.currency(
      locale: 'en_US',
      symbol: 'Rp ',
      decimalDigits: 2,
    ).format(record.number(key));
    final color = switch (record.status) {
      'Approved' || 'Paid' => Colors.green,
      'Rejected' => Colors.red,
      'Cancelled' => Colors.grey,
      _ => Colors.orange,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              record.invoice,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(record.text('customer')),
            if (_approvals) Text('Created By: ${record.text('created_by')}'),
            const SizedBox(height: 6),
            Text(
              record.statusLabel,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              'Total: ${money('jumlah_total')}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Request Details'),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Company: ${record.text('company_name')}'),
                      Text('Invoice Date: ${record.text('tanggal_penagihan')}'),
                      Text('Due Date: ${record.text('tanggal_jatuhtempo')}'),
                      Text('Amount: ${money('jumlah')}'),
                      Text('VAT: ${money('ppn')}'),
                      Text('Withholding Tax (PPh): ${money('pph')}'),
                      Text('Administration Fee: ${money('admin')}'),
                      Text('Amount in Words: ${record.text('terbilang')}'),
                      for (final entry in {
                        'pembayaran_tahap': 'Payment Stage',
                        'jumlah_lampiran': 'Attachment Count',
                        'keterangan': 'Description',
                        'informasi_transfer': 'Transfer Information',
                        'rejected_note': 'Rejection Reason',
                      }.entries)
                        if (record.text(entry.key).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${entry.value}: ${record.text(entry.key)}',
                            ),
                          ),
                      if (record.data['has_attachment'] == true)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('Attachment saved'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (_approvals && record.canApprove)
              Wrap(
                spacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: busy ? null : () => _decide(record, false),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => _decide(record, true),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                  ),
                ],
              ),
            if (!_approvals && record.canCancel)
              TextButton.icon(
                onPressed: busy ? null : () => _cancel(record),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _decide(PaymentModel record, bool reject) async {
    var reason = '';
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          reject ? 'Reject Payment Application' : 'Approve Payment Application',
        ),
        scrollable: true,
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${record.text('created_by')}\nPayment #${record.id}\nAmount: Rp ${record.text('jumlah_total')}',
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
    final notifier = ref.read(paymentApprovalProvider.notifier);
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
              : ref.read(paymentApprovalProvider).submitError ??
                    'Unable to process this request.',
        ),
      ),
    );
    await notifier.load();
  }
}
