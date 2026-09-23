import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';

class ApiStub implements HttpClientAdapter {
  final FutureOr<ResponseBody> Function(RequestOptions) respond;
  ApiStub(this.respond);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object data, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

Map<String, dynamic> historyRow(int id) => {
  'id': id,
  'date': '2026-09-18',
  'formatted_date': '18 September 2026',
};
Map<String, dynamic> leaveRow(int id) => {
  'id': id,
  'jenis_cuti': 'Cuti Tahunan',
  'tanggal_mulai': '2026-09-18',
  'tanggal_selesai': '2026-09-18',
  'jumlah_hari': 1,
  'alasan': 'Keperluan keluarga',
  'status': 'pending',
  'approval_level': 1,
};
