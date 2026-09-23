import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../providers/attendance_provider.dart';
import '../../../core/utils/attendance_location.dart';

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

  bool _isPreparingSubmission = false;
  bool _radiusVerified = false;
  bool _isOutsideRadius = false;

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
      _radiusVerified = false;
    });

    try {
      await Future.wait([_initCamera(), _getLocation()]);
      if (!mounted) return;
      await _checkRadius();
    } catch (e) {
      if (!mounted) return; // ← tambah ini
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  /// Setup kamera depan (selfie).
  Future<void> _initCamera() async {
    final previous = _cameraController;
    _cameraController = null;
    _isCameraReady = false;
    await previous?.dispose();
    if (!mounted) return;
    final status = await Permission.camera.request();
    if (!mounted) return;

    if (status.isDenied || status.isPermanentlyDenied) {
      throw Exception(
        'Camera permission denied. Enable camera access in app settings.',
      );
    }

    _cameras = await availableCameras();
    if (!mounted) return;

    if (_cameras.isEmpty) {
      throw Exception('No camera is available.');
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
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
        'Location services are disabled. Enable them in your device settings.',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is blocked. Enable location access in app settings.',
      );
    }

    _currentPosition = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
    AttendanceLocation.validate(_currentPosition!);
  }

  /// Cek apakah posisi user berada di luar radius kantor.
  Future<void> _checkRadius() async {
    _radiusVerified = false;
    final repo = ref.read(attendanceRepositoryProvider);
    final office = await repo.getOfficeLocation();
    if (!mounted) return;
    if (office == null || _currentPosition == null) {
      throw StateError(
        'The office location is unavailable. Contact your administrator.',
      );
    }
    AttendanceLocation.validate(_currentPosition!);

    final distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      office.latitude,
      office.longitude,
    );

    if (!mounted) return; // ← tambah ini juga sebelum setState

    setState(() {
      _radiusVerified = true;
      _isOutsideRadius = distance > office.radius;
    });
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
      if (!mounted) return;
      setState(() {
        _capturedPhoto = File(xFile.path);
        _isCapturing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to capture photo: $e';
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
                hintText: 'Enter your reason...',
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
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('A reason is required.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.of(context).pop(controller.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Submit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Submit clock-in atau clock-out.
  Future<void> _submit() async {
    if (_capturedPhoto == null ||
        _isPreparingSubmission ||
        ref.read(attendanceProvider).isSubmitting) {
      return;
    }
    setState(() => _isPreparingSubmission = true);
    try {
      final isClockOut = widget.isClockOut;
      String? reason;
      String? locationReason;

      // Cek dialog alasan terlambat/pulang awal
      if (!isClockOut && _isLateNow()) {
        reason = await _showReasonDialog(
          title: 'Late Arrival',
          hint:
              'You are clocking in after 08:30.\nPlease provide a reason for your late arrival.',
        );
        if (!mounted || reason == null) return;
      } else if (isClockOut && _isEarlyLeaveNow()) {
        reason = await _showReasonDialog(
          title: 'Early Departure',
          hint:
              'You are clocking out before 17:00.\nPlease provide a reason for leaving early.',
        );
        if (!mounted || reason == null) return;
      }

      // Refresh again after a reason dialog, which may stay open for minutes.
      while (true) {
        await _getLocation();
        if (!mounted) return;
        await _checkRadius();
        if (!mounted) return;
        if (!_radiusVerified) {
          throw StateError(
            'The office attendance radius has not been verified.',
          );
        }
        if (!_isOutsideRadius || locationReason != null) break;
        locationReason = await _showReasonDialog(
          title: 'Outside Office Radius',
          hint:
              'You are outside the office attendance radius.\nPlease provide a reason, such as a client meeting or business travel.',
        );
        if (!mounted || locationReason == null) return;
      }
      AttendanceLocation.validate(_currentPosition!);

      final notifier = ref.read(attendanceProvider.notifier);
      bool success;

      if (isClockOut) {
        success = await notifier.clockOut(
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          photo: _capturedPhoto!,
          reason: reason,
          locationReason: locationReason,
        );
      } else {
        success = await notifier.clockIn(
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          photo: _capturedPhoto!,
          reason: reason,
          locationReason: locationReason,
        );
      }

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isClockOut
                  ? 'Clock-out recorded successfully.'
                  : 'Clock-in recorded successfully.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        final error =
            ref.read(attendanceProvider).errorMessage ??
            'The operation failed.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attendance was not submitted: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPreparingSubmission = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting =
        ref.watch(attendanceProvider).isSubmitting || _isPreparingSubmission;
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
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Preparing camera and GPS...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (_capturedPhoto != null) {
      return _buildPreview(isSubmitting);
    }

    return _buildCamera();
  }

  /// Live preview kamera + info GPS + tombol capture.
  Widget _buildCamera() {
    return Stack(
      children: [
        if (_isCameraReady)
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: _cameraController!.value.previewSize!.height,
                height: _cameraController!.value.previewSize!.width,
                child: CameraPreview(_cameraController!),
              ),
            ),
          ),

        // Info GPS di bagian atas — sekarang tampil warning kalau di luar radius
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _isOutsideRadius
                  ? Colors.orange.withOpacity(0.9)
                  : Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  _isOutsideRadius ? Icons.warning_amber : Icons.location_on,
                  color: _isOutsideRadius ? Colors.white : Colors.green,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _isOutsideRadius
                        ? 'Outside office radius'
                        : (_radiusVerified
                              ? 'Within office radius'
                              : 'Office radius not verified'),
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
                'Position your face inside the circle',
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
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(_capturedPhoto!, fit: BoxFit.cover),

              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isOutsideRadius
                        ? Colors.orange.withOpacity(0.85)
                        : Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isOutsideRadius
                                ? Icons.warning_amber
                                : Icons.location_on,
                            color: _isOutsideRadius
                                ? Colors.white
                                : Colors.green,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isOutsideRadius
                                ? 'Outside Office Radius'
                                : 'GPS Location',
                            style: TextStyle(
                              color: _isOutsideRadius
                                  ? Colors.white
                                  : Colors.green,
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
                        'Accuracy: ${_currentPosition?.accuracy.toStringAsFixed(0)}m',
                        style: TextStyle(color: Colors.grey[300], fontSize: 11),
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
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () => setState(() => _capturedPhoto = null),
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text(
                    'Retake Photo',
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
                        ? 'Processing...'
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
