import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/auth_provider.dart';
import '../constants/app_config.dart';

final attendancePhotoProvider = FutureProvider.autoDispose
    .family<List<int>, String>((ref, url) async {
      // Discard photos when the signed-in account changes.
      final user = ref.watch(authProvider.select((state) => state.user));
      if (user == null) throw StateError('Sign in to view attendance photos.');
      final client = ref.watch(apiClientProvider);
      final session = client.sessionVersion;
      final base = Uri.parse(client.dio.options.baseUrl);
      final uri = base.resolve(AppConfig.fixImageUrl(url));
      if (uri.origin != base.origin || uri.userInfo.isNotEmpty) {
        throw StateError('The photo URL does not belong to this server.');
      }
      final cancel = CancelToken();
      ref.onDispose(() => cancel.cancel());
      final token = await client.getToken();
      if (token == null ||
          session != client.sessionVersion ||
          cancel.isCancelled) {
        throw StateError('Your session has changed. Sign in again.');
      }
      final response = await client.dio.get<List<int>>(
        uri.toString(),
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: false,
          headers: {'Accept': 'image/*'},
        ),
      );
      if (session != client.sessionVersion || cancel.isCancelled) {
        throw StateError('Your session has changed.');
      }
      return response.data!;
    });

class NetworkImageWithHost extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    Widget failure() =>
        errorWidget ??
        SizedBox(
          height: height ?? 200,
          width: width,
          child: Center(
            child: TextButton.icon(
              onPressed: () => ref.invalidate(attendancePhotoProvider(url)),
              icon: const Icon(Icons.refresh),
              label: const Text('Unable to load photo. Retry'),
            ),
          ),
        );
    return ref
        .watch(attendancePhotoProvider(url))
        .when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          loading: () =>
              loadingWidget ??
              SizedBox(
                height: height ?? 200,
                width: width,
                child: const Center(child: CircularProgressIndicator()),
              ),
          error: (_, _) => failure(),
          data: (bytes) => Image.memory(
            Uint8List.fromList(bytes),
            fit: fit,
            height: height,
            width: width,
            errorBuilder: (_, _, _) => failure(),
          ),
        );
  }
}
