import 'dart:io';
import 'package:chapter2/core/network/data_layer_exception.dart';
import 'package:dio/dio.dart';

class ApiClient {
  ApiClient({Dio? dioClient, String? baseUrl})
      : _dio = dioClient ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? 'http://localhost:3001',
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            );

  final Dio _dio;
  String? _authToken;

  void setAuthToken(String? token) {
    _authToken = token;
    if (token != null && token.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  String? get authToken => _authToken;

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      return response.data;
    } on DioException catch (e) {
      _handleDioException(e);
    } on SocketException catch (_) {
      throw NetworkException('No internet connection');
    } catch (e) {
      throw ServerException('Unexpected network error: $e');
    }
  }

  Future<dynamic> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.post(path, data: data, queryParameters: queryParameters);
      return response.data;
    } on DioException catch (e) {
      _handleDioException(e);
    } on SocketException catch (_) {
      throw NetworkException('No internet connection');
    } catch (e) {
      throw ServerException('Unexpected network error: $e');
    }
  }

  Future<dynamic> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.delete(path, data: data, queryParameters: queryParameters);
      return response.data;
    } on DioException catch (e) {
      _handleDioException(e);
    } on SocketException catch (_) {
      throw NetworkException('No internet connection');
    } catch (e) {
      throw ServerException('Unexpected network error: $e');
    }
  }

  void _handleDioException(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      throw NetworkException('Connection timed out');
    }

    if (e.type == DioExceptionType.connectionError) {
      throw NetworkException('Unable to reach server');
    }

    final statusCode = e.response?.statusCode;
    final message = e.response?.data is Map<String, dynamic>
        ? (e.response?.data['message']?.toString() ?? e.message ?? 'Server error')
        : e.message ?? 'Server error';

    if (statusCode == 401 || statusCode == 403) {
      throw UnauthorizedException(message);
    }

    throw ServerException(message, statusCode: statusCode);
  }
}
