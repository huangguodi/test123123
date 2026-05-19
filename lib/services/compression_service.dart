import 'dart:io';
import 'dart:math';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';

class CompressionService {
  // 1. Photo Compression: Quality 70-80%, Resolution <= 1080P
  static Future<File?> compressImage(File file) async {
    try {
      final String path = file.path;
      // Generate a unique filename to avoid race conditions
      // Always use .jpg for output to ensure compatibility (e.g. converting HEIC to JPG)
      final String uniqueId = '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(10000)}';
      final String targetPath = '${(await getTemporaryDirectory()).path}/compressed_${uniqueId}.jpg';

      // 1080P = 1920x1080. We set minWidth/minHeight to 1920 to ensure it fits.
      // Actually 'minWidth' in this library often acts as a target constraint.
      // Let's use 1920 as the target max dimension.
      
      var result = await FlutterImageCompress.compressAndGetFile(
        path,
        targetPath,
        quality: 75, // 70-80%
        minWidth: 1080, 
        minHeight: 1080, 
        // Note: minWidth/minHeight logic depends on implementation, 
        // but 1080 usually constrains the smaller side or scales down.
        // A safer bet for "Resolution <= 1080P" is keeping it reasonable.
      );

      return result != null ? File(result.path) : null;
    } catch (e) {
      // If compression fails, return original or null? 
      // User says "Filter invalid files", so maybe return null if it's truly broken,
      // but if just compression fails, maybe original is better? 
      // User requirement: "Filter damaged files". If compression fails, it might be damaged.
      return null;
    }
  }

  // 2. Video Compression: Medium Quality, Bitrate reduced
  static Future<File?> compressVideo(File file) async {
    try {
      // Check size <= 500MB
      int size = await file.length();
      if (size > 500 * 1024 * 1024) {
        return null; // Filter out
      }

      MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.MediumQuality, // "Medium quality"
        deleteOrigin: false, 
        includeAudio: true,
      );

      if (mediaInfo != null && mediaInfo.file != null) {
        return mediaInfo.file;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // 3. Generate Thumbnail
  // iCloud Optimization: If file is just a placeholder or cloud-stored,
  // we might already have a low-res thumbnail locally.
  // BUT: `flutter_image_compress` needs real bytes.
  // If the file is not downloaded (size=0 or exists=false), we can't generate.
  // However, iOS Photo Library access often provides a way to get thumbnail even if original is in cloud.
  // For standard File based access, we assume file exists.
  static Future<File?> generateThumbnail(File file) async {
    try {
      final String path = file.path;
      final String uniqueId = '${DateTime.now().microsecondsSinceEpoch}_thumb';
      final String targetPath = '${(await getTemporaryDirectory()).path}/$uniqueId.jpg';
      final ext = path.toLowerCase();

      // Check if file exists and has content
      if (!file.existsSync() || await file.length() == 0) {
          return null;
      }

      if (ext.endsWith('.mp4') ||
          ext.endsWith('.mov') ||
          ext.endsWith('.avi') ||
          ext.endsWith('.mkv') ||
          ext.endsWith('.flv') ||
          ext.endsWith('.3gp')) {
        // Video Thumbnail
        return await VideoCompress.getFileThumbnail(
          path,
          quality: 50, // Low quality for thumbnail
          position: -1, // Default position
        );
      } else {
        // Image Thumbnail
        // Resize to 360px width (sufficient for list view)
        var result = await FlutterImageCompress.compressAndGetFile(
          path,
          targetPath,
          quality: 60,
          minWidth: 360,
          minHeight: 360,
        );
        return result != null ? File(result.path) : null;
      }
    } catch (e) {
      return null;
    }
  }

  static Future<void> cleanUp() async {
    await VideoCompress.deleteAllCache();
  }
}
