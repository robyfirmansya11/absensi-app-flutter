import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/connectivity_provider.dart';
import '../../core/widgets/offline_banner.dart';
import 'attendance/history_screen.dart';
import 'attendance/clock_in_screen.dart';
import 'profile_screen.dart';
import 'cuti/cuti_screen.dart';
import 'cuti/cuti_approval_screen.dart';
import 'overtime/overtime_screen.dart';
import 'late_permit/late_permit_screen.dart';
import 'payment/payment_screen.dart';
import 'register_letter/register_letter_screen.dart';
import 'stamp/stamp_screen.dart';
import 'loan/loan_screen.dart';
import 'travel/travel_screen.dart';
import 'expense/expense_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      final notifier = ref.read(attendanceProvider.notifier);
      await notifier.loadToday();
      await notifier.loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final attendanceState = ref.watch(attendanceProvider);
    final connectivityAsync = ref.watch(connectivityProvider);
    final isOnline = connectivityAsync.asData?.value ?? true;
    final user = authState.user;
    final today = attendanceState.today;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/images/Logo_InSys.png', width: 28, height: 28),
            const SizedBox(width: 8),
            const Text(
              'InSys',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B4F8A),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history, color: Color(0xFF1B4F8A)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.person_outline, color: Color(0xFF1B4F8A)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner offline — muncul otomatis kalau tidak ada koneksi
          const OfflineBanner(),

          // Sisa body
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                if (!isOnline) return;
                final notifier = ref.read(attendanceProvider.notifier);
                await notifier.loadToday();
                await notifier.loadHistory();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting
                    Text(
                      'Hello, ${user?.name ?? "Employee"}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (user?.isUser == true)
                      Text(
                        [
                          if (user?.jabatan != null &&
                              user!.jabatan!.isNotEmpty)
                            user.jabatan!,
                          if (user?.department != null &&
                              user!.department!.isNotEmpty)
                            user.department!,
                        ].join(' · '),
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),

                    const SizedBox(height: 24),

                    // Card status absensi hari ini
                    _buildStatusCard(attendanceState.isLoading, today),

                    const SizedBox(height: 24),

                    // Error message
                    if (attendanceState.errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning,
                              color: Colors.red,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                attendanceState.errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Tombol Clock In — disabled kalau offline
                    if (today == null || !today.hasClockedIn)
                      _buildActionButton(
                        label: 'Clock In',
                        icon: Icons.login,
                        color: isOnline ? Colors.green : Colors.grey,
                        onTap: isOnline
                            ? () => _navigateToClockIn(isClockOut: false)
                            : () => _showOfflineSnackbar(context),
                      ),

                    // Tombol Clock Out — disabled kalau offline
                    if (today != null &&
                        today.hasClockedIn &&
                        !today.hasClockedOut)
                      _buildActionButton(
                        label: 'Clock Out',
                        icon: Icons.logout,
                        color: isOnline ? Colors.orange : Colors.grey,
                        onTap: isOnline
                            ? () => _navigateToClockIn(isClockOut: true)
                            : () => _showOfflineSnackbar(context),
                      ),

                    // Sudah clock out hari ini
                    if (today != null && today.hasClockedOut)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 8),
                            Text(
                              'Attendance completed for today',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 28),
                    _buildMonthlyRecap(),
                    const SizedBox(height: 20),

                    _buildMenuCategory(
                      title: 'HRIS',
                      icon: Icons.people_outline,
                      children: [
                        _buildMenuItem(
                          'Late Working Permits',
                          Icons.schedule,
                          const LatePermitScreen(),
                        ),
                        _buildMenuItem(
                          'Leave Requests',
                          Icons.calendar_today,
                          const CutiScreen(),
                        ),
                        _buildMenuItem(
                          'Overtime Requests',
                          Icons.more_time,
                          const OvertimeScreen(),
                        ),
                        _buildMenuItem(
                          'Travel Reimbursements',
                          Icons.business_center_outlined,
                          const TravelScreen(),
                        ),
                        _buildMenuItem(
                          'Attendance Records',
                          Icons.history,
                          const HistoryScreen(),
                        ),
                        if (user?.canReviewLeave == true)
                          _buildMenuItem(
                            'Leave Approvals',
                            Icons.fact_check_outlined,
                            const CutiApprovalScreen(),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildMenuCategory(
                      title: 'Finance, Accounting & Tax',
                      icon: Icons.account_balance_outlined,
                      children: [
                        _buildMenuItem(
                          'Loan Note',
                          Icons.payments_outlined,
                          const LoanScreen(),
                        ),
                        _buildMenuItem(
                          'Payment Application Letter',
                          Icons.request_quote_outlined,
                          const PaymentScreen(),
                        ),
                        _buildMenuItem(
                          'Expense Reimbursement Note',
                          Icons.receipt_long_outlined,
                          const ExpenseScreen(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildMenuCategory(
                      title: 'Legal & Litigation',
                      icon: Icons.gavel_outlined,
                      children: [
                        _buildMenuItem(
                          'Register Letters',
                          Icons.description_outlined,
                          const RegisterLetterScreen(),
                        ),
                        _buildMenuItem(
                          'Stamp Application Letter',
                          Icons.approval_outlined,
                          const StampScreen(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCategory({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E5ED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF1B4F8A), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B4F8A),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 52, endIndent: 16),
            children[i],
          ],
        ],
      ),
    );
  }

  Widget _buildMenuItem(String label, IconData icon, Widget screen) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF1B4F8A)),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
    );
  }

  Widget _buildStatusCard(bool isLoading, today) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[600]!, Colors.blue[800]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today\'s Attendance',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildTimeBox(
                      label: 'Clock In',
                      time: today?.clockIn ?? '--:--',
                      icon: Icons.login,
                    ),
                    const SizedBox(width: 16),
                    _buildTimeBox(
                      label: 'Clock Out',
                      time: today?.clockOut ?? '--:--',
                      icon: Icons.logout,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Office Hours: 08:00 – 17:00',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
                if (today?.status != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(
                        today!.status!,
                      ).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(today.status!),
                      style: TextStyle(
                        color: _statusColor(today.status!),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildTimeBox({
    required String label,
    required String time,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyRecap() {
    final history = ref.watch(attendanceProvider).history;

    if (history.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    final thisMonth = history.where((h) {
      try {
        final date = DateTime.parse(h.date);
        return date.month == now.month && date.year == now.year;
      } catch (_) {
        return false;
      }
    }).toList();

    final totalHadir = thisMonth.where((h) => h.status == 'present').length;
    final totalTerlambat = thisMonth.where((h) => h.status == 'late').length;
    final totalAbsen = thisMonth.where((h) => h.status == 'absent').length;
    final totalHari = thisMonth.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Monthly Attendance Summary',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildRekapCard(
              label: 'Present',
              value: totalHadir,
              total: totalHari,
              color: Colors.green,
              icon: Icons.check_circle_outline,
            ),
            const SizedBox(width: 10),
            _buildRekapCard(
              label: 'Late',
              value: totalTerlambat,
              total: totalHari,
              color: Colors.orange,
              icon: Icons.access_time,
            ),
            const SizedBox(width: 10),
            _buildRekapCard(
              label: 'Absent',
              value: totalAbsen,
              total: totalHari,
              color: Colors.red,
              icon: Icons.cancel_outlined,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRekapCard({
    required String label,
    required int value,
    required int total,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
            if (total > 0) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: value / total,
                  backgroundColor: color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'present':
        return Colors.greenAccent;
      case 'late':
        return Colors.orangeAccent;
      case 'absent':
        return Colors.redAccent;
      default:
        return Colors.white;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'present':
        return 'On Time';
      case 'late':
        return 'Late';
      case 'absent':
        return 'Absent';
      default:
        return status;
    }
  }

  void _showOfflineSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('No internet connection.'),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _navigateToClockIn({required bool isClockOut}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ClockInScreen(isClockOut: isClockOut)),
    );

    if (result == true && mounted) {
      final notifier = ref.read(attendanceProvider.notifier);
      await notifier.loadToday();
      await notifier.loadHistory();
    }
  }
}
