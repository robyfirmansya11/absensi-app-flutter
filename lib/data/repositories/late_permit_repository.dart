import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/late_permit_model.dart';

class LatePermitRepository {
  final ApiClient client;
  LatePermitRepository(this.client);

  Future<List<LatePermitModel>> getList({bool approvals = false}) async {
    final session = client.sessionVersion;
    final records = <int, LatePermitModel>{};
    var page = 1;
    try {
      while (true) {
        if (session != client.sessionVersion) {
          throw StateError('Your session has changed.');
        }
        final response = await client.dio.get(
          approvals
              ? '${ApiConstants.latePermit}/approvals'
              : ApiConstants.latePermit,
          queryParameters: {'page': page},
        );
        if (session != client.sessionVersion) {
          throw StateError('Your session has changed.');
        }
        final body = response.data as Map<String, dynamic>;
        final oldCount = records.length;
        for (final row in body['data'] as List) {
          final record = LatePermitModel.fromJson(
            Map<String, dynamic>.from(row),
          );
          records[record.id] = record;
        }
        if (page >= (body['last_page'] as num).toInt()) break;
        if (oldCount == records.length) {
          throw const FormatException('Invalid late arrival pagination.');
        }
        page++;
      }
      return records.values.toList();
    } on DioException catch (e) {
      throw _message(e);
    }
  }

  Future<LatePermitModel> create(LatePermitDraft draft) async {
    try {
      final response = await client.dio.post(
        ApiConstants.latePermit,
        data: draft.toJson(),
      );
      return LatePermitModel.fromJson(
        Map<String, dynamic>.from(response.data['data']),
      );
    } on DioException catch (e) {
      throw _message(e);
    }
  }

  Future<LatePermitModel> cancel(int id) async {
    try {
      final response = await client.dio.post(
        '${ApiConstants.latePermit}/$id/cancel',
      );
      return LatePermitModel.fromJson(
        Map<String, dynamic>.from(response.data['data']),
      );
    } on DioException catch (e) {
      throw _message(e);
    }
  }

  Future<LatePermitModel> decide(int id, {String? rejectionReason}) async {
    try {
      final response = await client.dio.post(
        '${ApiConstants.latePermit}/$id/${rejectionReason == null ? 'approve' : 'reject'}',
        data: rejectionReason == null
            ? null
            : {'rejected_note': rejectionReason.trim()},
      );
      return LatePermitModel.fromJson(
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
