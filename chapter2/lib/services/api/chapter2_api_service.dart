import 'package:dio/dio.dart';

class Chapter2ApiService {
  Chapter2ApiService({Dio? dioClient, String? baseUrl})
      : _dio = dioClient ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? 'http://localhost:3000',
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
                headers: {'Content-Type': 'application/json'},
              ),
            );

  final Dio _dio;

  Future<List<Map<String, dynamic>>> fetchActions() async {
    try {
      final response = await _dio.get<List<dynamic>>('/actions');
      if (response.data == null) return [];
      return response.data!.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchActionById(String actionId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/actions/$actionId');
      return response.data;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> approveAction(String actionId, Map<String, dynamic> approvalPayload) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/actions/$actionId/approve',
        data: approvalPayload,
      );
      return response.data;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> verifyWorldIdSelfie(Map<String, dynamic> proofPayload) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/world/verify-selfie',
        data: proofPayload,
      );
      return response.data;
    } catch (_) {
      return null;
    }
  }
}
