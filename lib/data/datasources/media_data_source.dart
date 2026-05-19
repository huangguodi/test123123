import 'dart:io';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class MediaDataSource {
  /// 获取媒体文件，支持增量扫描（通过外部传入最后处理的时间戳）
  Stream<File> getMediaFiles({DateTime? lastScanTime}) async* {
    if (!await _checkPermission()) return;

    // 使用过滤条件：按时间倒序
    final FilterOptionGroup filterOptions = FilterOptionGroup(
      orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
    );

    if (lastScanTime != null) {
      filterOptions.createTimeCond = DateTimeCond(
        min: lastScanTime,
        max: DateTime.now(),
      );
    }

    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      filterOption: filterOptions,
    );

    for (final path in paths) {
      final int count = await path.assetCountAsync;
      const int pageSize = 50; // 分页加载，减少单次内存压力

      for (int i = 0; i < count; i += pageSize) {
        final List<AssetEntity> assets = await path.getAssetListRange(
          start: i,
          end: (i + pageSize) < count ? (i + pageSize) : count,
        );

        // 2026 Fix: Parallel processing with concurrency limit (Batch of 5)
        // Solves I/O bottleneck in serial execution
        const int batchSize = 5;
        for (int j = 0; j < assets.length; j += batchSize) {
          final end = (j + batchSize < assets.length) ? j + batchSize : assets.length;
          final batch = assets.sublist(j, end);
          
          final results = await Future.wait(batch.map((e) => e.file));
          
          for (final file in results) {
            if (file != null) {
              yield file;
            }
          }
        }
      }
    }
  }

  Future<bool> _checkPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      // 2026 Fix: Align permission check with SplashPage logic
      // SDK <= 32 (Android 12L) uses READ_EXTERNAL_STORAGE
      if (androidInfo.version.sdkInt <= 32) {
        return await Permission.storage.isGranted;
      } else {
        // SDK >= 33 (Android 13) uses granular permissions
        bool photos = await Permission.photos.isGranted;
        bool videos = await Permission.videos.isGranted;
        // Allow partial access (e.g. only photos or only videos)
        return photos || videos;
      }
    } else {
      return await Permission.photos.isGranted ||
          await Permission.photos.isLimited;
    }
  }
}
