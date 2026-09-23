import '../../../core/utils/english_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/cuti_provider.dart';
import 'create_cuti_screen.dart';
import 'cuti_approval_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cuti_approval_provider.dart';

class CutiScreen extends ConsumerStatefulWidget {
  const CutiScreen({super.key});

  @override
  ConsumerState<CutiScreen> createState() => _CutiScreenState();
}

class _CutiScreenState extends ConsumerState<CutiScreen> {
  bool _approvals = false;
  @override
  void initState() {
    super.initState();
    _approvals = ref.read(authProvider).user?.canReviewLeave == true;
    Future.microtask(() {
      if (mounted) ref.read(cutiProvider.notifier).loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cutiProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          'Leave Requests',
          style: TextStyle(
            color: Color(0xFF1B4F8A),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1B4F8A),
        elevation: 0,
        bottom: ref.watch(authProvider).user?.canReviewLeave == true
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
                    onSelectionChanged:
                        ref.watch(cutiApprovalProvider).isProcessing
                        ? null
                        : (values) {
                            setState(() => _approvals = values.single);
                            if (!_approvals) {
                              ref.read(cutiProvider.notifier).loadAll();
                            }
                          },
                  ),
                ),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF1B4F8A)),
            tooltip: 'New Request',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateCutiScreen()),
              );
              if (mounted) {
                ref.read(cutiProvider.notifier).loadAll();
              }
            },
          ),
        ],
      ),
      body: _approvals
          ? const CutiApprovalScreen(embedded: true)
          : Column(
              children: [
                // Quota Card
                if (state.quota != null)
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        _buildQuotaItem(
                          label: 'Total Quota',
                          value: state.quota!.kuotaTahunan,
                          color: const Color(0xFF1B4F8A),
                        ),
                        _buildQuotaItem(
                          label: 'Used',
                          value: state.quota!.cutiTerpakai,
                          color: Colors.orange,
                        ),
                        _buildQuotaItem(
                          label: 'Remaining',
                          value: state.quota!.sisaCuti,
                          color: Colors.green,
                        ),
                      ],
                    ),
                  ),

                const Divider(height: 1),

                // List
                Expanded(
                  child: state.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : state.list.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          onRefresh: () =>
                              ref.read(cutiProvider.notifier).loadAll(),
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: state.list.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) => _buildCard(state.list[i]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildQuotaItem({
    required String label,
    required int value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          Text('days', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildCard(cuti) {
    final color = _statusColor(cuti.status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 90,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        EnglishUi.leaveType(cuti.jenisCuti),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          cuti.status,
                          style: TextStyle(
                            fontSize: 10,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${EnglishUi.date(cuti.tanggalMulai)} — ${EnglishUi.date(cuti.tanggalSelesai)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    '${cuti.jumlahHari} days',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  if (cuti.status == 'Pending Approval' ||
                      cuti.status == 'Submitted')
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12, top: 4),
                        child: GestureDetector(
                          onTap: () => _confirmCancel(cuti.id),
                          child: const Text(
                            'Cancel Request',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
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

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No leave requests yet',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateCutiScreen()),
            ),
            icon: const Icon(Icons.add),
            label: const Text('New Request'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B4F8A),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Request'),
        content: const Text(
          'Are you sure you want to cancel this leave request?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final success = await ref.read(cutiProvider.notifier).cancel(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Request cancelled.' : 'Failed to cancel.'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Color _statusColor(String status) {
    return switch (status) {
      'Approved' => Colors.green,
      'Pending Approval' => Colors.orange,
      'Rejected' => Colors.red,
      'Cancelled' => Colors.grey,
      _ => Colors.grey,
    };
  }
}
