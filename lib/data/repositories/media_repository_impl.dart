import 'dart:io';
import '../datasources/media_data_source.dart';
import '../../domain/repositories/media_repository.dart';

class MediaRepositoryImpl implements IMediaRepository {
  final MediaDataSource _dataSource;

  MediaRepositoryImpl(this._dataSource);

  @override
  Stream<File> getMediaFiles({DateTime? lastScanTime}) =>
      _dataSource.getMediaFiles(lastScanTime: lastScanTime);
}
