import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hiway_app/core/constants/app_constants.dart';
import '../services/orchestrator_service.dart';

class ServiceFactory {
  static final ServiceFactory _instance = ServiceFactory._internal();
  factory ServiceFactory() => _instance;
  ServiceFactory._internal();

  static final _dio = Dio(BaseOptions(
    baseUrl: dotenv.env['API_BASE'] ?? AppConstants.apiBase,
    connectTimeout: const Duration(minutes: 4),
    receiveTimeout: const Duration(minutes: 5),
    sendTimeout: const Duration(minutes: 5),
  ));

  static OrchestratorService get orchestrator => OrchestratorService(dio: _dio);
}
