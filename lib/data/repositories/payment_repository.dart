import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/payment_model.dart';

class PaymentRepository {
  final ApiClient client;
  PaymentRepository(this.client);

  Future<List<PaymentCompany>> getCompanies() async {
    try {
      final response = await client.dio.get(
        '${ApiConstants.payment}/companies',
      );
      return (response.data as List)
          .map((e) => PaymentCompany.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw _message(e);
    }
  }

  Future<List<PaymentModel>> getList({bool approvals = false}) async {
    final session = client.sessionVersion;
    final records = <int, PaymentModel>{};
    var page = 1;
    try {
      while (true) {
        if (session != client.sessionVersion) {
          throw StateError('Your session has changed.');
        }
        final response = await client.dio.get(
          approvals
              ? '${ApiConstants.payment}/approvals'
              : ApiConstants.payment,
          queryParameters: {'page': page},
        );
        if (session != client.sessionVersion) {
          throw StateError('Your session has changed.');
        }
        final body = response.data as Map<String, dynamic>;
        final oldCount = records.length;
        for (final row in body['data'] as List) {
          final record = PaymentModel.fromJson(Map<String, dynamic>.from(row));
          records[record.id] = record;
        }
        if (page >= (body['last_page'] as num).toInt()) break;
        if (oldCount == records.length) {
          throw const FormatException('Invalid payment pagination.');
        }
        page++;
      }
      return records.values.toList();
    } on DioException catch (e) {
      throw _message(e);
    }
  }

  Future<PaymentModel> create(PaymentDraft draft) async {
    final session = client.sessionVersion;
    try {
      final fields = draft.toJson();
      final attachment = draft.attachment;
      fields['lampiran'] = attachment.bytes != null
          ? MultipartFile.fromBytes(
              attachment.bytes!,
              filename: attachment.name,
            )
          : await MultipartFile.fromFile(
              attachment.path!,
              filename: attachment.name,
            );
      if (session != client.sessionVersion) {
        throw StateError('Your session has changed. Please sign in again.');
      }
      final response = await client.dio.post(
        ApiConstants.payment,
        data: FormData.fromMap(fields),
      );
      return PaymentModel.fromJson(
        Map<String, dynamic>.from(response.data['data']),
      );
    } on DioException catch (e) {
      throw _message(e);
    }
  }

  Future<PaymentModel> cancel(int id) async {
    try {
      final response = await client.dio.post(
        '${ApiConstants.payment}/$id/cancel',
      );
      return PaymentModel.fromJson(
        Map<String, dynamic>.from(response.data['data']),
      );
    } on DioException catch (e) {
      throw _message(e);
    }
  }

  Future<PaymentModel> decide(int id, {String? rejectionReason}) async {
    try {
      final response = await client.dio.post(
        '${ApiConstants.payment}/$id/${rejectionReason == null ? 'approve' : 'reject'}',
        data: rejectionReason == null
            ? null
            : {'rejected_note': rejectionReason.trim()},
      );
      return PaymentModel.fromJson(
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
