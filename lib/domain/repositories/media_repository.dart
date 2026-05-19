import 'dart:io';

abstract class IMediaRepository {
  Stream<File> getMediaFiles({DateTime? lastScanTime});
}
