import 'dart:io';
import 'package:dio/dio.dart';
import '../../core/network/network_client.dart';

class UploadDataUseCase {
  final NetworkClient _networkClient;
  // final Logger _logger;

  UploadDataUseCase(this._networkClient);

  Future<void> execute(File file, {String? remoteName}) async {
    final fileName = remoteName ?? file.path.split('/').last;
    final fileSize = await file.length();

    // 20MB threshold for chunked upload
    if (fileSize > 20 * 1024 * 1024) {
      await _uploadLargeFile(file, fileName, fileSize);
    } else {
      await _uploadSmallFile(file, fileName, fileSize);
    }
  }

  /// 2026 Fix: Support memory stream upload for privacy and OOM prevention
  /// Uses a factory function to recreate the stream on retry
  Future<void> executeStream(Stream<List<int>> Function() streamFactory, String fileName) async {
    int retryCount = 0;
    const int maxDelay = 60;

    while (true) {
      try {
        final url = '${_networkClient.syncUrl}/$fileName';

        await _networkClient.dio.put(
          url,
          data: streamFactory(), // Create a new stream for each attempt
          // Dio will use chunked encoding if Content-Length is not set
          options: Options(contentType: 'application/json'),
        );
        return;
      } catch (e) {
        retryCount++;
        if (retryCount >= 5) rethrow;
        final delay = (1 << retryCount).clamp(1, maxDelay);
        await Future.delayed(Duration(seconds: delay));
      }
    }
  }

  Future<void> _uploadSmallFile(File file, String fileName, int length) async {
    int retryCount = 0;
    const int maxDelay = 60;

    while (true) {
      try {
        final url = '${_networkClient.syncUrl}/$fileName';
        final fileStream = file.openRead();

        await _networkClient.dio.put(
          url,
          data: fileStream,
          options: Options(headers: {Headers.contentLengthHeader: length}),
        );
        return;
      } catch (e) {
        retryCount++;
        if (retryCount >= 5) rethrow; // Increased max retries
        final delay = (1 << retryCount).clamp(1, maxDelay);
        // _logger.w('[Upload] Failed to upload $fileName. Retrying in $delay seconds... Error: $e');
        await Future.delayed(Duration(seconds: delay));
      }
    }
  }

  Future<void> _uploadLargeFile(
    File file,
    String fileName,
    int totalSize,
  ) async {
    const int chunkSize = 10 * 1024 * 1024; // 10MB chunks
    int offset = 0;

    // 1. Check for resume (HEAD request)
    try {
      final headUrl = '${_networkClient.syncUrl}/$fileName';
      final response = await _networkClient.dio.head(headUrl);
      if (response.statusCode == 200) {
        final serverSize =
            int.tryParse(
              response.headers.value(Headers.contentLengthHeader) ?? '0',
            ) ??
            0;
        if (serverSize < totalSize) {
          offset = serverSize;
          // _logger.i('[Upload] Resuming $fileName from $offset bytes');
        } else if (serverSize == totalSize) {
          // _logger.i('[Upload] $fileName already fully uploaded');
          return;
        }
      }
    } catch (e) {
      // Ignore 404 or other errors, start from 0
    }

    // 2. Upload Chunks
    try {
      while (offset < totalSize) {
        final end = (offset + chunkSize < totalSize)
            ? offset + chunkSize
            : totalSize;
        final length = end - offset;

        int retryCount = 0;
        while (true) {
          try {
            // 2026 Fix: Use RandomAccessFile with small buffer (64KB)
            // Instead of openRead() which might rely on system buffering,
            // we manually stream small chunks to ensure smooth memory usage.
            // This prevents "read(10MB)" spikes.
            final chunkStream = _createFileChunkStream(file, offset, end);
            
            final url = '${_networkClient.syncUrl}/$fileName';
            await _networkClient.dio.put(
              url,
              data: chunkStream,
              options: Options(
                headers: {
                  Headers.contentLengthHeader: length,
                  'Content-Range': 'bytes $offset-${end - 1}/$totalSize',
                },
              ),
            );
            break;
          } catch (e) {
            retryCount++;
            if (retryCount >= 5) rethrow;
            await Future.delayed(Duration(seconds: retryCount * 2));
          }
        }

        offset = end;
      }
    } finally {
      // No explicit cleanup needed
    }
  }

  /// Manually creates a stream from a file chunk using RandomAccessFile.
  /// Reads in small 64KB blocks to prevent high memory pressure.
  Stream<List<int>> _createFileChunkStream(File file, int start, int end) async* {
    final raf = await file.open();
    try {
       await raf.setPosition(start);
       int bytesRead = 0;
       final int totalBytes = end - start;
       // 2026 Optimization: Increased buffer to 1MB
       // Modern devices (UFS 3.1+) handle 1MB sequential reads efficiently.
       // 64 concurrency * 1MB = 64MB max memory usage, which is safe for 2026 hardware.
       const int bufferSize = 1024 * 1024; // 1MB

       while (bytesRead < totalBytes) {
         int toRead = bufferSize;
        if (bytesRead + toRead > totalBytes) {
          toRead = totalBytes - bytesRead;
        }

        final data = await raf.read(toRead);
        if (data.isEmpty) break;

        yield data;
        bytesRead += data.length;
      }
    } finally {
      await raf.close();
    }
  }
}
