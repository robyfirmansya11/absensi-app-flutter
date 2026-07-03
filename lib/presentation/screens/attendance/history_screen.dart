import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/attendance_provider.dart';
import 'attendance_detail_screen.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.read(attendanceProvider.notifier).loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Riwayat Absensi")),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(AttendanceState state) {
    if (state.isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.history.isEmpty) {
      return const Center(
        child: Text(
          "Belum ada riwayat absensi",
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(attendanceProvider.notifier).loadHistory();
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: state.history.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = state.history[index];

          return Card(
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _statusColor(item.status),
                child: Icon(Icons.access_time, color: Colors.white),
              ),
              title: Text(item.date),
              subtitle: Text(
                "Masuk : ${item.clockIn ?? '-'}\n"
                "Pulang : ${item.clockOut ?? '-'}",
              ),
              trailing: Chip(
                label: Text(_statusLabel(item.status)),
                backgroundColor: _statusColor(item.status).withOpacity(.15),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AttendanceDetailScreen(attendance: item),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Color _statusColor(String? status) {
    switch (status) {
      case "present":
        return Colors.green;

      case "late":
        return Colors.orange;

      case "absent":
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case "present":
        return "Hadir";

      case "late":
        return "Terlambat";

      case "absent":
        return "Tidak Hadir";

      default:
        return "-";
    }
  }
}
