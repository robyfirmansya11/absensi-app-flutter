import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../models/cuti_approval_model.dart';

class CutiApprovalRepository {
  final ApiClient _apiClient;

  CutiApprovalRepository(this._apiClient);

  /// List pengajuan cuti yang menunggu approval dari user yang login.
  Future<List<CutiApprovalModel>> getApprovalList() async {
    try {
      final response = await _apiClient.dio.get('/cuti/approvals');
      final data = response.data as List;
      return data.map((e) => CutiApprovalModel.fromJson(e)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Approve pengajuan cuti.
  Future<void> approve(int id) async {
    try {
      await _apiClient.dio.post('/cuti/$id/approve');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Reject pengajuan cuti dengan alasan.
  Future<void> reject(int id, String rejectedNote) async {
    try {
      await _apiClient.dio.post(
        '/cuti/$id/reject',
        data: {'rejected_note': rejectedNote},
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    final errors = e.response?.data is Map ? e.response!.data['errors'] : null;
    if (errors is Map) {
      return errors.values
          .expand((value) => value is List ? value : [value])
          .join('\n');
    }
    if (e.response?.data is Map && e.response!.data['message'] != null) {
      return e.response!.data['message'] as String;
    }
    return 'Something went wrong. Please try again.';
  }
}
