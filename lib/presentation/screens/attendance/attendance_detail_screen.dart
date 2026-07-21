import 'package:flutter/material.dart';

import '../../../data/models/attendance_model.dart';
import '../../../core/utils/url_helper.dart';
import '../../../core/widgets/network_image_with_host.dart';

/// Halaman detail absensi.
/// Menampilkan informasi lengkap satu record absensi karyawan,
/// meliputi tanggal, status kehadiran, jam clock in/out,
/// foto clock in/out, lokasi, dan catatan (jika ada).
class AttendanceDetailScreen extends StatelessWidget {
  final AttendanceHistoryModel attendance;

  const AttendanceDetailScreen({super.key, required this.attendance});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Detail Absensi")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionTitle("Tanggal"),
          _infoCard(Icons.calendar_today, attendance.date),

          const SizedBox(height: 20),

          _sectionTitle("Status"),
          _statusCard(),

          const SizedBox(height: 20),

          _sectionTitle("Jam"),
          Row(
            children: [
              Expanded(
                child: _infoCard(Icons.login, attendance.clockIn ?? "-"),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoCard(Icons.logout, attendance.clockOut ?? "-"),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Section foto clock in hanya ditampilkan jika URL foto tersedia.
          if (attendance.clockInPhoto != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle("Foto Clock In"),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: NetworkImageWithHost(
                    url: UrlHelper.fixUrl(attendance.clockInPhoto!),
                    fit: BoxFit.cover,
                    height: 250,
                  ),
                ),
              ],
            ),

          const SizedBox(height: 20),

          // Section foto clock out hanya ditampilkan jika URL foto tersedia.
          if (attendance.clockOutPhoto != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle("Foto Clock Out"),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: NetworkImageWithHost(
                    url: UrlHelper.fixUrl(attendance.clockOutPhoto!),
                    fit: BoxFit.cover,
                    height: 250,
                  ),
                ),
              ],
            ),

          // Section lokasi pulang (clock out) hanya ditampilkan jika alamat tersedia.
          if (attendance.clockOutAddress != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _sectionTitle("Lokasi Pulang"),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(attendance.clockOutAddress!),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 20),

          // Section lokasi masuk (clock in) hanya ditampilkan jika alamat tersedia.
          if (attendance.clockInAddress != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle("Lokasi Masuk"),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(attendance.clockInAddress!),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 20),

          // Section catatan hanya ditampilkan jika note tidak null dan tidak kosong.
          if (attendance.note != null && attendance.note!.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle("Catatan"),
                Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(attendance.note!),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // Widget helper untuk menampilkan judul section (label) di atas setiap blok informasi.
  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  // Widget helper generik untuk menampilkan satu baris info dalam bentuk Card.
  Widget _infoCard(IconData icon, String text) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget khusus untuk menampilkan status kehadiran (present/late/absent).
  Widget _statusCard() {
    Color color;
    String text;

    switch (attendance.status) {
      case "present":
        color = Colors.green;
        text = "Hadir";
        break;
      case "late":
        color = Colors.orange;
        text = "Terlambat";
        break;
      case "absent":
        color = Colors.red;
        text = "Tidak Hadir";
        break;
      default:
        color = Colors.grey;
        text = "-";
    }

    return Card(
      color: color.withValues(alpha: .12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(Icons.verified, color: color),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
