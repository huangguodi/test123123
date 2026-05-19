import 'package:logger/logger.dart';
import '../../core/network/network_client.dart';
import '../../core/di/service_locator.dart';

class FetchConfigUseCase {
  final NetworkClient _networkClient;
  // final Logger _logger = getIt<Logger>();

  FetchConfigUseCase(this._networkClient);

  Future<Map<String, dynamic>?> execute() async {
    try {
      final String cacheBuster = 't=${DateTime.now().millisecondsSinceEpoch}';
      final String targetUrl = _networkClient.indexUrl.contains('?')
          ? '${_networkClient.indexUrl}&$cacheBuster'
          : '${_networkClient.indexUrl}?$cacheBuster';

      print('DEBUG: Init Request URL: $targetUrl'); // Temporary Debug Log

      final response = await _networkClient.initDio.get(targetUrl);

      print(
        'DEBUG: Init Response Status: ${response.statusCode}',
      ); // Temporary Debug Log
      print(
        'DEBUG: Init Response Data: ${response.data}',
      ); // Temporary Debug Log

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        print(
          'DEBUG: FetchConfigUseCase: Unexpected status code ${response.statusCode}',
        ); // Temporary Debug Log
        // _logger.w('FetchConfigUseCase: Unexpected status code ${response.statusCode}');
      }
    } catch (e) {
      print('DEBUG: FetchConfigUseCase Error: $e'); // Temporary Debug Log
      // _logger.e('FetchConfigUseCase Error: $e');
    }
    return null;
  }
}
