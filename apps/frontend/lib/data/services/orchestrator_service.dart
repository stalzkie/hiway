// lib/services/orchestrator_service.dart
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hiway_app/data/models/orchestrator_models.dart';

class OrchestratorService {
  final Dio _dio;

  OrchestratorService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(minutes: 4),
              receiveTimeout: const Duration(minutes: 5),
              sendTimeout: const Duration(minutes: 5),
            ));

  // ✅ Use .env with fallback
  String get _base =>
      (dotenv.env['API_BASE'] ?? 'http://10.0.2.2:8000').replaceAll(RegExp(r'/+$'), '');

  /// POST /api/orchestrate?email=...&role=...&force=true
  Future<OrchestratorResponse> runOrchestrator({
    required String email,
    String? role,
    bool force = false,
  }) async {
    final qp = {
      'email': email,
      if (role != null && role.isNotEmpty) 'role': role,
      if (force) 'force': 'false',
    };

    final uri = Uri.parse('$_base/api/orchestrate')
        .replace(queryParameters: qp)
        .toString();

    print('DEBUG: Calling orchestrator service at: $uri');
    print('DEBUG: Query parameters: $qp');

    try {
      final res = await _dio.post(
        uri,
        data: const {}, // no body, just query params
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) {
            return status != null && status < 500;
          },
        ),
      );

      if (res.statusCode != 200) {
        print('DEBUG: Non-200 response: ${res.data}');
        throw DioException(
          requestOptions: res.requestOptions,
          response: res,
          error: 'Server returned ${res.statusCode}: ${res.data}',
        );
      }

      if (res.data == null) {
        throw DioException(
          requestOptions: res.requestOptions,
          response: res,
          error: 'Server returned empty response',
        );
      }

      print('DEBUG: Successfully received response: ${res.data}');
      return OrchestratorResponse.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      print('DEBUG: Exception during request: $e');
      if (e is DioException && e.response?.data != null) {
        print('DEBUG: Server error response: ${e.response?.data}');
      }
      rethrow;
    }
  }
}
