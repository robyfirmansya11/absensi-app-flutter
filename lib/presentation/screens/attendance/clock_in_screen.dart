import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../providers/attendance_provider.dart';

class ClockInScreen extends ConsumerStatefulWidget {
  final bool isClockOut;

  const ClockInScreen({super.key, this.isClockOut = false});

  @override
  ConsumerState<ClockInScreen> createState() => _ClockInScreenState();
}

class _ClockInScreenState extends ConsumerState<ClockInScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];

  bool _isInitializing = true;
  bool _isCameraReady = false;
  bool _isCapturing = false;

  File? _capturedPhoto;
  Position? _currentPosition;

  String? _errorMessage;

  String? _reason;

  @override
  void initState() {
    super.initState();
    _initializeAll();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  /// Inisialisasi kamera dan ambil lokasi GPS secara paralel.
  Future<void> _initializeAll() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      await Future.wait([_initCamera(), _getLocation()]);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() => _isInitializing = false);
    }
  }

  /// Setup kamera depan (selfie).
  Future<void> _initCamera() async {
    // Request permission kamera dulu sebelum init
    final status = await Permission.camera.request();

    if (status.isDenied || status.isPermanentlyDenied) {
      throw Exception('Izin kamera ditolak. Aktifkan di pengaturan aplikasi.');
    }

    _cameras = await availableCameras();

    if (_cameras.isEmpty) {
      throw Exception('Tidak ada kamera yang tersedia.');
    }

    final frontCamera = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();

    if (mounted) {
      setState(() => _isCameraReady = true);
    }
  }

  /// Minta izin lokasi dan ambil koordinat GPS.
  Future<void> _getLocation() async {
    // Cek service GPS aktif atau tidak
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
        'GPS tidak aktif. Nyalakan GPS di pengaturan perangkat Anda.',
      );
    }

    // Cek dan minta permission lokasi
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Izin lokasi ditolak.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Izin lokasi ditolak permanen. Aktifkan di pengaturan aplikasi.',
      );
    }

    // Ambil posisi saat ini
    _currentPosition = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }

  /// Ambil foto selfie.
  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (_isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      final xFile = await _cameraController!.takePicture();
      setState(() {
        _capturedPhoto = File(xFile.path);
        _isCapturing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal mengambil foto: $e';
        _isCapturing = false;
      });
    }
  }

  bool _isLateNow() {
    final now = DateTime.now();
    final lateThreshold = DateTime(now.year, now.month, now.day, 8, 30);
    return now.isAfter(lateThreshold);
  }

  bool _isEarlyLeaveNow() {
    final now = DateTime.now();
    final checkoutTime = DateTime(now.year, now.month, now.day, 17, 0);
    return now.isBefore(checkoutTime);
  }

  Future<String?> _showReasonDialog({
    required String title,
    required String hint,
  }) async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(hint, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Tulis alasan di sini...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Alasan tidak boleh kosong.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.of(context).pop(controller.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Kirim', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Submit clock-in atau clock-out.
  Future<void> _submit() async {
    if (_capturedPhoto == null || _currentPosition == null) return;

    final isClockOut = widget.isClockOut;
    String? reason;

    // Cek apakah perlu dialog alasan
    if (!isClockOut && _isLateNow()) {
      reason = await _showReasonDialog(
        title: '⚠️ Anda Terlambat',
        hint:
            'Anda clock in setelah pukul 08:30.\nMohon isi alasan keterlambatan.',
      );
      if (reason == null) return; // user tekan Batal
    } else if (isClockOut && _isEarlyLeaveNow()) {
      reason = await _showReasonDialog(
        title: '⚠️ Pulang Lebih Awal',
        hint:
            'Anda clock out sebelum pukul 17:00.\nMohon isi alasan pulang lebih awal.',
      );
      if (reason == null) return; // user tekan Batal
    }

    final notifier = ref.read(attendanceProvider.notifier);
    bool success;

    if (isClockOut) {
      success = await notifier.clockOut(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        photo: _capturedPhoto!,
        reason: reason,
      );
    } else {
      success = await notifier.clockIn(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        photo: _capturedPhoto!,
        reason: reason,
      );
    }

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isClockOut ? 'Clock Out berhasil!' : 'Clock In berhasil!',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      final error = ref.read(attendanceProvider).errorMessage ?? 'Gagal.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = ref.watch(attendanceProvider).isSubmitting;
    final isClockOut = widget.isClockOut;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(isClockOut ? 'Clock Out' : 'Clock In'),
      ),
      body: _buildBody(isSubmitting),
    );
  }

  Widget _buildBody(bool isSubmitting) {
    // Error state
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initializeAll,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    // Loading state
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Menyiapkan kamera & GPS...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    // Foto sudah diambil — tampilkan preview + tombol submit
    if (_capturedPhoto != null) {
      return _buildPreview(isSubmitting);
    }

    // Tampilkan live kamera
    return _buildCamera();
  }

  /// Live preview kamera + info GPS + tombol capture.
  Widget _buildCamera() {
    return Stack(
      children: [
        // Camera preview dengan aspect ratio yang benar
        if (_isCameraReady)
          SizedBox.expand(
            child: FittedBox(
              // Pakai contain supaya tidak gepeng
              // Ganti ke fill kalau mau fullscreen (tapi bisa crop)
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: _cameraController!.value.previewSize!.height,
                height: _cameraController!.value.previewSize!.width,
                child: CameraPreview(_cameraController!),
              ),
            ),
          ),

        // Info GPS di bagian atas
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.green, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _currentPosition != null
                        ? 'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}\n'
                              'Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}'
                        : 'Mengambil lokasi...',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Panduan selfie di tengah
        Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withOpacity(0.7),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        ),

        // Tombol capture di bawah
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Text(
                'Posisikan wajah di dalam lingkaran',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _isCapturing ? null : _capturePhoto,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.grey, width: 3),
                  ),
                  child: _isCapturing
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.camera_alt,
                          size: 32,
                          color: Colors.black,
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Preview foto yang sudah diambil + tombol submit atau retake.
  Widget _buildPreview(bool isSubmitting) {
    return Column(
      children: [
        // Preview foto
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(_capturedPhoto!, fit: BoxFit.cover),

              // Info GPS overlay
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.green,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Lokasi GPS',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Lat: ${_currentPosition?.latitude.toStringAsFixed(6)}\n'
                        'Lng: ${_currentPosition?.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        'Akurasi: ${_currentPosition?.accuracy.toStringAsFixed(0)}m',
                        style: TextStyle(color: Colors.grey[400], fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Tombol aksi
        Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            children: [
              // Tombol retake (ambil ulang)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () => setState(() => _capturedPhoto = null),
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text(
                    'Ulangi',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Tombol submit
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: isSubmitting ? null : _submit,
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(widget.isClockOut ? Icons.logout : Icons.login),
                  label: Text(
                    isSubmitting
                        ? 'Memproses...'
                        : widget.isClockOut
                        ? 'Clock Out'
                        : 'Clock In',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.isClockOut
                        ? Colors.orange
                        : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
