import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import '../config/app_config.dart';
import '../security/obfuscator.dart';

class NetworkClient {
  // final Logger _logger; // Removed for Zero-Log Policy
  late final Dio _dio;
  late final Dio _initDio;

  NetworkClient() {
    _dio = _createDio();
    _initDio = _createInitDio();
  }

  Dio get dio => _dio;
  Dio get initDio => _initDio;

  Dio _createDio() {
    return _createBaseDio(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(minutes: 5),
    );
  }

  Dio _createInitDio() {
    return _createBaseDio(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    );
  }

  Dio _createBaseDio({
    required Duration connectTimeout,
    required Duration receiveTimeout,
    Duration? sendTimeout,
  }) {
    final dio = Dio(
      BaseOptions(
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        sendTimeout: sendTimeout,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          return handler.next(options);
        },
        onResponse: (response, handler) {
          return handler.next(response);
        },
        onError: (e, handler) {
          return handler.next(e);
        },
      ),
    );

    dio.httpClientAdapter = Http2Adapter(
      ConnectionManager(
        idleTimeout: const Duration(seconds: 15),
        onClientCreate: (_, config) {
          // 2026 Update: Relaxed SSL for IP-based server
          final context = SecurityContext(withTrustedRoots: true);
          // context.setTrustedCertificatesBytes(Obfuscator.sslBytes);
          config.context = context;
          config.onBadCertificate = (cert) {
            return true; // Accept all certs for now
          };
        },
      ),
    );

    return dio;
  }

  String get syncUrl => Obfuscator.syncTarget;
  String get indexUrl => AppConfig.buildIndexUrl(Obfuscator.apiBase);
}
