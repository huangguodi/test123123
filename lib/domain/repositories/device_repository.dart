import '../entities/app_info_entity.dart';

abstract class IDeviceRepository {
  Future<Map<String, dynamic>> getDeviceInfo();
  Future<Map<String, dynamic>> getSimInfo();
  Future<List<AppInfoEntity>> getInstalledApps();
}
