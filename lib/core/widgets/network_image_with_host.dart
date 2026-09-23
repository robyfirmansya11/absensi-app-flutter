import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';

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

  Future<List<int>> _downloadImage() async {
    final dio = Dio();

    final response = await dio.get<List<int>>(
      widget.url,
      options: Options(responseType: ResponseType.bytes),
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
          Uint8List.fromList(snapshot.data!),
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
