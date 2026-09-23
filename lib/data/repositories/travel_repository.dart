import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/travel_model.dart';

class TravelRepository {
  final ApiClient client;
  TravelRepository(this.client);

  Future<List<TravelCompany>> getCompanies() async {
    try {
      final response = await client.dio.get('${ApiConstants.travel}/companies');
      return (response.data as List)
          .map((e) => TravelCompany.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw _message(e);
    }
  }

  Future<List<TravelModel>> getList({bool approvals = false}) async {
    final session = client.sessionVersion;
    final records = <int, TravelModel>{};
    var page = 1;
    try {
      while (true) {
        if (session != client.sessionVersion) {
          throw StateError('Your session has changed.');
        }
        final response = await client.dio.get(
          approvals ? '${ApiConstants.travel}/approvals' : ApiConstants.travel,
          queryParameters: {'page': page},
        );
        if (session != client.sessionVersion) {
          throw StateError('Your session has changed.');
        }
        final body = response.data as Map<String, dynamic>;
        final oldCount = records.length;
        for (final row in body['data'] as List) {
          final record = TravelModel.fromJson(Map<String, dynamic>.from(row));
          records[record.id] = record;
        }
        if (page >= (body['last_page'] as num).toInt()) break;
        if (oldCount == records.length) {
          throw const FormatException('Invalid request pagination.');
        }
        page++;
      }
      return records.values.toList();
    } on DioException catch (e) {
      throw _message(e);
    }
  }

  Future<TravelModel> save(TravelDraft draft, {int? id}) async {
    final session = client.sessionVersion;
    try {
      final fields = draft.toJson();
      if (session != client.sessionVersion) {
        throw StateError('Your session has changed.');
      }
      final response = await client.dio.post(
        id == null ? ApiConstants.travel : '${ApiConstants.travel}/$id',
        data: fields,
      );
      return TravelModel.fromJson(
        Map<String, dynamic>.from(response.data['data']),
      );
    } on DioException catch (e) {
      throw _message(e);
    }
  }

  Future<TravelModel> cancel(int id) async {
    try {
      final response = await client.dio.post(
        '${ApiConstants.travel}/$id/cancel',
      );
      return TravelModel.fromJson(
        Map<String, dynamic>.from(response.data['data']),
      );
    } on DioException catch (e) {
      throw _message(e);
    }
  }

  Future<TravelModel> decide(int id, {String? rejectionReason}) async {
    try {
      final response = await client.dio.post(
        '${ApiConstants.travel}/$id/${rejectionReason == null ? 'approve' : 'reject'}',
        data: rejectionReason == null
            ? null
            : {'rejected_note': rejectionReason.trim()},
      );
      return TravelModel.fromJson(
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
