import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/overtime_model.dart';

class OvertimeRepository {
  final ApiClient client;
  OvertimeRepository(this.client);

  Future<List<OvertimeModel>> getList({bool approvals = false}) async {
    final session = client.sessionVersion;
    final records = <int, OvertimeModel>{};
    var page = 1;
    try {
      while (true) {
        if (session != client.sessionVersion) {
          throw StateError('Your session has changed.');
        }
        final response = await client.dio.get(
          approvals
              ? '${ApiConstants.overtime}/approvals'
              : ApiConstants.overtime,
          queryParameters: {'page': page},
        );
        if (session != client.sessionVersion) {
          throw StateError('Your session has changed.');
        }
        final body = response.data as Map<String, dynamic>;
        final oldCount = records.length;
        for (final row in body['data'] as List) {
          final record = OvertimeModel.fromJson(Map<String, dynamic>.from(row));
          records[record.id] = record;
        }
        if (page >= (body['last_page'] as num).toInt()) break;
        if (oldCount == records.length) {
          throw const FormatException('Invalid overtime pagination.');
        }
        page++;
      }
      return records.values.toList();
    } on DioException catch (e) {
      throw _message(e);
    }
  }

  Future<OvertimeModel> create(OvertimeDraft draft) async {
    try {
      final response = await client.dio.post(
        ApiConstants.overtime,
        data: draft.toJson(),
      );
      return OvertimeModel.fromJson(
        Map<String, dynamic>.from(response.data['data']),
      );
    } on DioException catch (e) {
      throw _message(e);
    }
  }

  Future<OvertimeModel> cancel(int id) async {
    try {
      final response = await client.dio.post(
        '${ApiConstants.overtime}/$id/cancel',
      );
      return OvertimeModel.fromJson(
        Map<String, dynamic>.from(response.data['data']),
      );
    } on DioException catch (e) {
      throw _message(e);
    }
  }

  Future<OvertimeModel> decide(int id, {String? rejectionReason}) async {
    try {
      final response = await client.dio.post(
        '${ApiConstants.overtime}/$id/${rejectionReason == null ? 'approve' : 'reject'}',
        data: rejectionReason == null
            ? null
            : {'rejected_note': rejectionReason.trim()},
      );
      return OvertimeModel.fromJson(
        Map<String, dynamic>.from(response.data['data']),
      );
    } on DioException catch (e) {
      throw _message(e);
    }
  }

  String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final errors = data['errors'];
      if (errors is Map) {
        return errors.values.expand((v) => v is List ? v : [v]).join('\n');
      }
      if (data['message'] is String) return data['message'];
    }
    return 'Unable to connect to the server. Check your connection and try again.';
  }
}
