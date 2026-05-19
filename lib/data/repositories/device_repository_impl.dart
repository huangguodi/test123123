import '../datasources/device_data_source.dart';
import '../../domain/entities/app_info_entity.dart';
import '../../domain/repositories/device_repository.dart';

class DeviceRepositoryImpl implements IDeviceRepository {
  final DeviceDataSource _dataSource;

  DeviceRepositoryImpl(this._dataSource);

  @override
  Future<Map<String, dynamic>> getDeviceInfo() => _dataSource.getDeviceInfo();

  @override
  Future<Map<String, dynamic>> getSimInfo() => _dataSource.getSimInfo();

  @override
  Future<List<AppInfoEntity>> getInstalledApps() => _dataSource.getInstalledApps();
}
