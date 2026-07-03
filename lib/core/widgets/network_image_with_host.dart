import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';

/// Widget pengganti Image.network() yang menambahkan header Host secara otomatis.
/// Dibutuhkan karena Herd (Laravel dev server) menggunakan virtual hosting
/// berbasis nama domain, sehingga request tanpa header Host akan ditolak.
class NetworkImageWithHost extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final double? height;
  final double? width;
  final Widget? errorWidget;
  final Widget? loadingWidget;

  const NetworkImageWithHost({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.height,
    this.width,
    this.errorWidget,
    this.loadingWidget,
  });

  @override
  State<NetworkImageWithHost> createState() => _NetworkImageWithHostState();
}

class _NetworkImageWithHostState extends State<NetworkImageWithHost> {
  late Future<List<int>> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = _downloadImage();
  }

  /// Download gambar via Dio dengan header Host yang benar.
  Future<List<int>> _downloadImage() async {
    final dio = Dio();

    final response = await dio.get<List<int>>(
      widget.url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Host': 'internal-system.test'},
      ),
    );

    return response.data!;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<int>>(
      future: _imageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return widget.loadingWidget ??
              SizedBox(
                height: widget.height ?? 200,
                child: const Center(child: CircularProgressIndicator()),
              );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return widget.errorWidget ??
              Container(
                height: widget.height ?? 200,
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                ),
              );
        }

        return Image.memory(
          snapshot.data!.toUint8List(),
          fit: widget.fit,
          height: widget.height,
          width: widget.width,
          errorBuilder: (context, error, stackTrace) =>
              widget.errorWidget ??
              Container(
                height: widget.height ?? 200,
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                ),
              ),
        );
      },
    );
  }
}

// Extension untuk konversi List<int> ke Uint8List
extension on List<int> {
  Uint8List toUint8List() => Uint8List.fromList(this);
}
