import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/network/api_client.dart';
import '../models/cuti_model.dart';

class CutiRepository {
  final ApiClient _apiClient;

  CutiRepository(this._apiClient);

  Future<List<CutiModel>> getList() async {
    try {
      final response = await _apiClient.dio.get('/cuti');
      final data = response.data as List;
      return data.map((e) => CutiModel.fromJson(e)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<KuotaCutiModel> getQuota() async {
    try {
      final response = await _apiClient.dio.get('/cuti/quota');
      return KuotaCutiModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Buat pengajuan cuti baru. [lampiran] wajib diisi kalau jenisCuti == 'Cuti Sakit'.
  Future<CutiModel> create({
    required String jenisCuti,
    required String tanggalMulai,
    required String tanggalSelesai,
    required String alasan,
    PlatformFile? lampiran,
  }) async {
    try {
      final formData = FormData.fromMap({
        'jenis_cuti': jenisCuti,
        'tanggal_mulai': tanggalMulai,
        'tanggal_selesai': tanggalSelesai,
        'alasan': alasan,
        if (lampiran != null && lampiran.path != null)
          'lampiran': await MultipartFile.fromFile(
            lampiran.path!,
            filename: lampiran.name,
          ),
      });

      final response = await _apiClient.dio.post('/cuti', data: formData);
      return CutiModel.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> cancel(int id) async {
    try {
      await _apiClient.dio.post('/cuti/$id/cancel');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.response?.data is Map && e.response!.data['message'] != null) {
      return e.response!.data['message'] as String;
    }
    return 'Something went wrong. Please try again.';
  }
}
