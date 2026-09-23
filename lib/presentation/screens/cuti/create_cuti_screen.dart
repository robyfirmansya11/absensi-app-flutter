import '../../../core/utils/english_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/cuti_provider.dart';

class CreateCutiScreen extends ConsumerStatefulWidget {
  const CreateCutiScreen({super.key});

  @override
  ConsumerState<CreateCutiScreen> createState() => _CreateCutiScreenState();
}

class _CreateCutiScreenState extends ConsumerState<CreateCutiScreen> {
  final _formKey = GlobalKey<FormState>();
  final _alasanController = TextEditingController();

  String? _selectedJenis;
  DateTime? _tanggalMulai;
  DateTime? _tanggalSelesai;
  PlatformFile? _lampiran;

  final List<String> _jenisCutiOptions = [
    'Cuti Tahunan',
    'Cuti Haid',
    'Cuti Khusus',
    'Cuti Melahirkan',
    'Cuti Keguguran',
    'Cuti Sakit',
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(cutiProvider.notifier).loadAll());
  }

  @override
  void dispose() {
    _alasanController.dispose();
    super.dispose();
  }

  int get _jumlahHari {
    if (_tanggalMulai == null || _tanggalSelesai == null) return 0;
    return _tanggalSelesai!.difference(_tanggalMulai!).inDays + 1;
  }

  Future<void> _pickLampiran() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _lampiran = result.files.first);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_tanggalMulai == null || _tanggalSelesai == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select start and end date.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Lampiran wajib untuk Cuti Sakit
    if (_selectedJenis == 'Cuti Sakit' && _lampiran == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please attach a medical certificate for Sick Leave.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final fmt = DateFormat('yyyy-MM-dd');
    final success = await ref
        .read(cutiProvider.notifier)
        .create(
          jenisCuti: _selectedJenis!,
          tanggalMulai: fmt.format(_tanggalMulai!),
          tanggalSelesai: fmt.format(_tanggalSelesai!),
          alasan: _alasanController.text.trim(),
          lampiran: _lampiran,
        );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Leave request submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      final error = ref.read(cutiProvider).errorMessage ?? 'Failed to submit.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cutiProvider);
    final quota = state.quota;
    final isSubmitting = state.isSubmitting;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          'New Leave Request',
          style: TextStyle(
            color: Color(0xFF1B4F8A),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1B4F8A),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quota Info
              if (quota != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Color(0xFF1B4F8A),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Remaining annual leave: ${quota.sisaCuti} days',
                        style: const TextStyle(
                          color: Color(0xFF1B4F8A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // Jenis Cuti
              const Text(
                'Leave Type',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedJenis,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  hintText: 'Select leave type',
                ),
                items: _jenisCutiOptions.map((j) {
                  return DropdownMenuItem(
                    value: j,
                    child: Text(EnglishUi.leaveType(j)),
                  );
                }).toList(),
                onChanged: (v) => setState(() {
                  _selectedJenis = v;
                  // Reset lampiran kalau ganti jenis bukan Cuti Sakit
                  if (v != 'Cuti Sakit') _lampiran = null;
                }),
                validator: (v) => v == null ? 'Please select leave type' : null,
              ),

              const SizedBox(height: 16),

              // Tanggal Mulai
              const Text(
                'Start Date',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() {
                      _tanggalMulai = picked;
                      if (_tanggalSelesai != null &&
                          _tanggalSelesai!.isBefore(picked)) {
                        _tanggalSelesai = picked;
                      }
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: Color(0xFF1B4F8A),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _tanggalMulai == null
                            ? 'Select start date'
                            : DateFormat('dd MMMM yyyy').format(_tanggalMulai!),
                        style: TextStyle(
                          color: _tanggalMulai == null
                              ? Colors.grey
                              : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Tanggal Selesai
              const Text(
                'End Date',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _tanggalMulai ?? DateTime.now(),
                    firstDate: _tanggalMulai ?? DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => _tanggalSelesai = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: Color(0xFF1B4F8A),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _tanggalSelesai == null
                            ? 'Select end date'
                            : DateFormat(
                                'dd MMMM yyyy',
                              ).format(_tanggalSelesai!),
                        style: TextStyle(
                          color: _tanggalSelesai == null
                              ? Colors.grey
                              : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Jumlah Hari
              if (_jumlahHari > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: Colors.green[700],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Duration: $_jumlahHari day(s)',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Lampiran — wajib untuk Cuti Sakit
              if (_selectedJenis == 'Cuti Sakit') ...[
                const SizedBox(height: 16),
                const Text(
                  'Medical Certificate (Required)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickLampiran,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: _lampiran == null
                            ? Colors.grey[400]!
                            : Colors.green,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _lampiran == null
                              ? Icons.upload_file
                              : Icons.check_circle,
                          size: 18,
                          color: _lampiran == null
                              ? const Color(0xFF1B4F8A)
                              : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _lampiran?.name ?? 'Select file (PDF, JPG, PNG)',
                            style: TextStyle(
                              color: _lampiran == null
                                  ? Colors.grey
                                  : Colors.black,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_lampiran != null)
                          GestureDetector(
                            onTap: () => setState(() => _lampiran = null),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.red,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Alasan
              const Text(
                'Reason',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _alasanController,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Describe the reason for your leave request...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please provide a reason'
                    : null,
              ),

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B4F8A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Submit Request',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
