import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/register_letter_model.dart';

class RegisterLetterRepository {
  final ApiClient client;
  RegisterLetterRepository(this.client);

  Future<List<RegisterLetterCompany>> getCompanies() async {
    try {
      final response = await client.dio.get(
        '${ApiConstants.registerLetter}/companies',
      );
      return (response.data as List)
          .map(
            (e) => RegisterLetterCompany.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    } on DioException catch (e) {
      throw _message(e);
    }
  }

  Future<List<RegisterLetterModel>> getList() async {
    final session = client.sessionVersion;
    final records = <int, RegisterLetterModel>{};
    var page = 1;
    try {
      while (true) {
        if (session != client.sessionVersion) {
          throw StateError('Your session has changed.');
        }
        final response = await client.dio.get(
          ApiConstants.registerLetter,
          queryParameters: {'page': page},
        );
        if (session != client.sessionVersion) {
          throw StateError('Your session has changed.');
        }
        final body = response.data as Map<String, dynamic>;
        final oldCount = records.length;
        for (final row in body['data'] as List) {
          final record = RegisterLetterModel.fromJson(
            Map<String, dynamic>.from(row),
          );
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

  Future<RegisterLetterModel> save(RegisterLetterDraft draft, {int? id}) async {
    final session = client.sessionVersion;
    try {
      final fields = draft.toJson();
      final attachment = draft.attachment;
      if (attachment != null) {
        fields['lampiran_surat'] = attachment.bytes != null
            ? MultipartFile.fromBytes(
                attachment.bytes!,
                filename: attachment.name,
              )
            : await MultipartFile.fromFile(
                attachment.path!,
                filename: attachment.name,
              );
      }
      if (session != client.sessionVersion) {
        throw StateError('Your session has changed.');
      }
      final response = await client.dio.post(
        id == null
            ? ApiConstants.registerLetter
            : '${ApiConstants.registerLetter}/$id',
        data: FormData.fromMap(fields),
      );
      return RegisterLetterModel.fromJson(
        Map<String, dynamic>.from(response.data['data']),
      );
    } on DioException catch (e) {
      throw _message(e);
    }
  }

  Future<void> delete(int id) async {
    try {
      await client.dio.delete('${ApiConstants.registerLetter}/$id');
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
