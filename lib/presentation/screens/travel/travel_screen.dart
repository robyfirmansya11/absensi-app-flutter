import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/travel_model.dart';
import '../../providers/travel_provider.dart';
import '../../providers/auth_provider.dart';
import 'travel_form_screen.dart';

class TravelScreen extends ConsumerStatefulWidget {
  const TravelScreen({super.key});
  @override
  ConsumerState<TravelScreen> createState() => _TravelScreenState();
}

class _TravelScreenState extends ConsumerState<TravelScreen> {
  String _search = '';
  bool _approvals = false;
  StateNotifierProvider<TravelNotifier, TravelState> get _provider =>
      _approvals ? travelApprovalProvider : travelProvider;
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

  Future<void> _edit([TravelModel? record]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TravelFormScreen(record: record)),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Travel reimbursement saved successfully.')),
    );
    await ref.read(_provider.notifier).load();
  }

  Future<void> _cancel(TravelModel record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this request?'),
        content: Text('Travel reimbursement #${record.id} will be cancelled.'),
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
            'total',
            'catatan',
            'company_name',
            'created_by',
            'keterangan',
          ].any((key) => r.text(key).toLowerCase().contains(_search)),
        )
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Travel Reimbursements'),
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
            tooltip: 'New travel reimbursement',
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
                                  : 'No travel reimbursements yet.')
                            : 'No matching travel reimbursements found.',
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
                              'Travel #${record.id}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Amount: ${NumberFormat.currency(locale: "en_US", symbol: "Rp ", decimalDigits: 2).format(double.tryParse(record.text('total')) ?? 0)}',
                            ),
                            Text(
                              'Amount in Words: ${record.text('terbilang')}',
                            ),
                            Text(
                              'Attachment Count: ${record.text('jumlah_lampiran')}',
                            ),
                            if (record.text('catatan').isNotEmpty)
                              Text('Notes: ${record.text('catatan')}'),
                            ExpansionTile(
                              title: const Text('Travel Details'),
                              children: [
                                for (final detail in record.details)
                                  ListTile(
                                    title: Text(
                                      '${detail['tempat_berangkat']} → ${detail['tempat_tujuan']}',
                                    ),
                                    subtitle: Text(
                                      '${detail['tanggal_berangkat']} ${detail['waktu_berangkat'] ?? ""} — ${detail['tanggal_tujuan']} ${detail['waktu_tujuan'] ?? ""}\nDays: ${detail['jumlah_hari']}, hotel nights: ${detail['lama_hotel']}\nTransport: ${detail['amount_transportasi']}, daily allowance: ${detail['amount_tunjangan']}\nNightly hotel rate: ${detail['amount_hotel']}, misc: ${detail['misc']}, other expenses: ${detail['amount_other']}\nSubtotal: Rp ${detail['subtotal']}',
                                    ),
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

  Future<void> _decide(TravelModel record, bool reject) async {
    var reason = '';
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          reject
              ? 'Reject Travel Reimbursement'
              : 'Approve Travel Reimbursement',
        ),
        scrollable: true,
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${record.text('created_by')}\nTravel #${record.id}\nAmount: Rp ${record.text('total')}',
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
    final notifier = ref.read(travelApprovalProvider.notifier);
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
              : ref.read(travelApprovalProvider).submitError ??
                    'Unable to process this request.',
        ),
      ),
    );
    await notifier.load();
  }
}
