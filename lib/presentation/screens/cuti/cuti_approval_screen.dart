import '../../../core/utils/english_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/cuti_approval_provider.dart';
import '../../../data/models/cuti_approval_model.dart';

class CutiApprovalScreen extends ConsumerStatefulWidget {
  final bool embedded;
  const CutiApprovalScreen({super.key, this.embedded = false});
  @override
  ConsumerState<CutiApprovalScreen> createState() => _CutiApprovalScreenState();
}

class _CutiApprovalScreenState extends ConsumerState<CutiApprovalScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(cutiApprovalProvider.notifier).loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cutiApprovalProvider);
    final body = state.isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: () => ref.read(cutiApprovalProvider.notifier).loadAll(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (state.errorMessage != null) ...[
                  Text(state.errorMessage!, textAlign: TextAlign.center),
                  TextButton(
                    onPressed: state.isProcessing
                        ? null
                        : () =>
                              ref.read(cutiApprovalProvider.notifier).loadAll(),
                    child: const Text('Try Again'),
                  ),
                ] else if (state.list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No requests awaiting your approval.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final request in state.list)
                  _card(request, state.isProcessing),
              ],
            ),
          );
    if (widget.embedded) return body;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(title: const Text('Leave Approvals')),
      body: body,
    );
  }

  Widget _card(CutiApprovalModel request, bool busy) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.employeeName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (request.department != null) Text(request.department!),
          const SizedBox(height: 8),
          Text(
            request.stageLabel,
            style: const TextStyle(color: Colors.orange),
          ),
          const SizedBox(height: 8),
          Text(
            EnglishUi.leaveType(request.jenisCuti),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            '${EnglishUi.date(request.tanggalMulai)} – ${EnglishUi.date(request.tanggalSelesai)} (${request.jumlahHari} days)',
          ),
          const SizedBox(height: 8),
          Text(request.alasan),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: [
              if (request.canApprove)
                FilledButton.icon(
                  onPressed: busy ? null : () => _decide(request, false),
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                ),
              if (request.canReject)
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _decide(request, true),
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                ),
            ],
          ),
        ],
      ),
    ),
  );

  Future<void> _decide(CutiApprovalModel request, bool reject) async {
    var reason = '';
    final form = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(reject ? 'Reject Leave Request' : 'Approve Leave Request'),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${request.employeeName}\n${EnglishUi.leaveType(request.jenisCuti)}\n${EnglishUi.date(request.tanggalMulai)} – ${EnglishUi.date(request.tanggalSelesai)}',
                ),
                const SizedBox(height: 12),
                if (!reject)
                  const Text(
                    'Approve this request at the current stage? The next step follows the leave approval workflow.',
                  ),
                if (reject)
                  TextFormField(
                    onChanged: (value) => reason = value.trim(),
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Reason for Rejection',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a reason for rejection.'
                        : null,
                  ),
              ],
            ),
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
            child: Text(reject ? 'Confirm Rejection' : 'Confirm Approval'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final notifier = ref.read(cutiApprovalProvider.notifier);
    final success = reject
        ? await notifier.reject(request.id, reason)
        : await notifier.approve(request.id);
    if (!mounted) return;
    final error = ref.read(cutiApprovalProvider).errorMessage;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (reject ? 'Leave request rejected.' : 'Leave request approved.')
              : error ?? 'Unable to process this request.',
        ),
      ),
    );
    if (!success) await notifier.loadAll();
  }
}
