import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/late_permit_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/late_permit_provider.dart';
import 'create_late_permit_screen.dart';

class LatePermitScreen extends ConsumerStatefulWidget {
  const LatePermitScreen({super.key});
  @override
  ConsumerState<LatePermitScreen> createState() => _LatePermitScreenState();
}

class _LatePermitScreenState extends ConsumerState<LatePermitScreen> {
  bool _approvals = false;
  StateNotifierProvider<LatePermitNotifier, LatePermitState> get _provider =>
      _approvals ? latePermitApprovalProvider : latePermitProvider;
  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _approvals = user?.isSuperuser == true || user?.isHRD == true;
    Future.microtask(() {
      if (mounted) ref.read(_provider.notifier).load();
    });
  }

  Future<void> _create() async {
    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateLatePermitScreen()),
    );
    if (!mounted || success != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Late arrival request submitted successfully.'),
      ),
    );
    await ref.read(_provider.notifier).load();
  }

  Future<void> _cancel(LatePermitModel record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this request?'),
        content: Text(
          'The late arrival request for ${record.date} will be cancelled.',
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
              ? 'Late arrival request cancelled.'
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
    final canReview = user?.isSuperuser == true || user?.isHRD == true;
    final canCreate = ref.watch(authProvider).user?.isSuperuser == false;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Late Working Permits'),
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
              tooltip: 'New late arrival request',
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
                  if (state.loadError != null) ...[
                    Text(state.loadError!, textAlign: TextAlign.center),
                    TextButton(
                      onPressed: () => ref.read(_provider.notifier).load(),
                      child: const Text('Try Again'),
                    ),
                  ] else if (state.records.isEmpty) ...[
                    const SizedBox(height: 80),
                    const Icon(Icons.more_time, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      _approvals
                          ? 'No requests awaiting your approval.'
                          : 'No late arrival requests yet.',
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

  Widget _card(LatePermitModel record, bool busy) {
    final color = switch (record.status) {
      'Approved' => Colors.green,
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
            if (_approvals) ...[
              Text(
                record.employeeName ?? 'Employee',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (record.departmentName != null) Text(record.departmentName!),
              const SizedBox(height: 8),
            ],
            Text(
              record.date,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              record.statusLabel,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text('Arrival Time: ${record.arrivalTime}'),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Request Details'),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(record.reason),
                      if (record.rejectedNote?.isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Rejection Reason: ${record.rejectedNote}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
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

  Future<void> _decide(LatePermitModel record, bool reject) async {
    var reason = '';
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(reject ? 'Reject Request' : 'Approve Request'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${record.employeeName ?? 'Employee'} • ${record.date} • ${record.arrivalTime}',
              ),
              const SizedBox(height: 12),
              Text(record.reason),
              if (!reject)
                Text(
                  record.approvalLevel == 1
                      ? 'This request will proceed according to the HR approval workflow.'
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
    final notifier = ref.read(latePermitApprovalProvider.notifier);
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
              : ref.read(latePermitApprovalProvider).submitError ??
                    'Unable to process this request.',
        ),
      ),
    );
    await notifier.load();
  }
}
