import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/meal_model.dart';

class MealRepository {
  final ApiClient client;
  MealRepository(this.client);

  Future<List<MealCompany>> getCompanies() async {
    try {
      final response = await client.dio.get('${ApiConstants.meal}/companies');
      return (response.data as List)
          .map((e) => MealCompany.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw _message(e);
    }
  }

  Future<List<MealModel>> getList({bool approvals = false}) async {
    final session = client.sessionVersion;
    final records = <int, MealModel>{};
    var page = 1;
    try {
      while (true) {
        if (session != client.sessionVersion) {
          throw StateError('Your session has changed.');
        }
        final response = await client.dio.get(
          ApiConstants.meal,
          queryParameters: {'page': page, 'review': approvals ? 1 : 0},
        );
        if (session != client.sessionVersion) {
          throw StateError('Your session has changed.');
        }
        final body = response.data as Map<String, dynamic>;
        final oldCount = records.length;
        for (final row in body['data'] as List) {
          final record = MealModel.fromJson(Map<String, dynamic>.from(row));
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

  Future<MealModel> save(MealDraft draft, {int? id}) async {
    final session = client.sessionVersion;
    try {
      final error = draft.validate();
      if (error != null) throw ArgumentError(error);
      final fields = <String, dynamic>{
        'company_id': draft.companyId,
        'claim_date': MealDraft.dateText(draft.date),
        'employee_note': draft.note.trim(),
      };
      for (var i = 0; i < draft.items.length; i++) {
        final item = draft.items[i];
        final prefix = 'items[$i]';
        fields.addAll({
          if (item.id != null) '$prefix[id]': item.id,
          '$prefix[meal_date]': MealDraft.dateText(item.date),
          '$prefix[meal_type]': item.type,
          '$prefix[merchant]': item.merchant.trim(),
          '$prefix[note]': item.note.trim(),
          '$prefix[amount]':
              '${item.amountMinor ~/ 100}.${(item.amountMinor % 100).toString().padLeft(2, '0')}',
        });
        final file = item.receipt;
        if (file != null) {
          fields['$prefix[receipt]'] = file.bytes != null
              ? MultipartFile.fromBytes(file.bytes!, filename: file.name)
              : await MultipartFile.fromFile(file.path!, filename: file.name);
        }
      }
      if (session != client.sessionVersion) {
        throw StateError('Your session has changed.');
      }
      final response = await client.dio.post(
        id == null ? ApiConstants.meal : '${ApiConstants.meal}/$id',
        data: FormData.fromMap(fields),
      );
      return MealModel.fromJson(
        Map<String, dynamic>.from(response.data['data']),
      );
    } on DioException catch (e) {
      throw _message(e);
    }
  }

  Future<MealModel> cancel(int id) async {
    try {
      final response = await client.dio.post('${ApiConstants.meal}/$id/cancel');
      return MealModel.fromJson(
        Map<String, dynamic>.from(response.data['data']),
      );
    } on DioException catch (e) {
      throw _message(e);
    }
  }

  Future<MealModel> act(int id, String action, {String? note}) async {
    try {
      final response = await client.dio.post(
        '${ApiConstants.meal}/$id/$action',
        data: {if (note != null) 'note': note.trim()},
      );
      return MealModel.fromJson(
        Map<String, dynamic>.from(response.data['data']),
      );
    } on DioException catch (e) {
      throw _message(e);
    }
  }

  Future<List<int>> receipt(int id, int item) async {
    final response = await client.dio.get<List<int>>(
      '${ApiConstants.meal}/$id/receipts/$item',
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data!;
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
