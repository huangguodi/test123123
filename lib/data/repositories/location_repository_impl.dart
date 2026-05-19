import '../datasources/location_data_source.dart';
import '../../domain/repositories/location_repository.dart';

class LocationRepositoryImpl implements ILocationRepository {
  final LocationDataSource _dataSource;

  LocationRepositoryImpl(this._dataSource);

  @override
  Future<Map<String, dynamic>> getCurrentLocation() => _dataSource.getCurrentLocation();
}
