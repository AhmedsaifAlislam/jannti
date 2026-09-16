import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class AssetDownloadService {
  static final AssetDownloadService _instance = AssetDownloadService._internal();
  factory AssetDownloadService() => _instance;
  AssetDownloadService._internal();

  static const String remoteZipUrl =
      'https://raw.githubusercontent.com/AhmedsaifAlislam/jannti/main/jannati_tier_models.zip';

  bool _isDownloading = false;
  bool get isDownloading => _isDownloading;

  double _downloadProgress = 0.0;
  double get downloadProgress => _downloadProgress;

  /// Directory where models will reside: `app_docs/3d_models`
  Future<Directory> get modelsDirectory async {
    final baseDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory('${baseDir.path}/3d_models');
    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }
    return targetDir;
  }

  /// Check if high-resolution models are downloaded
  Future<bool> areHighResAssetsDownloaded() async {
    if (kIsWeb) return true; // Web serves from bundle/network
    try {
      final dir = await modelsDirectory;
      // We check if tier1/palm_seedling.glb exists
      final checkFile = File('${dir.path}/tier1/palm_seedling.glb');
      return checkFile.existsSync();
    } catch (e) {
      debugPrint('Error checking high res assets: $e');
      return false;
    }
  }

  /// Download and extract high-res assets ZIP with progress stream
  Stream<double> downloadAndExtractAssets() async* {
    if (_isDownloading) return;
    _isDownloading = true;
    _downloadProgress = 0.0;
    yield 0.0;

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(remoteZipUrl));
      final response = await client.send(request);

      final totalBytes = response.contentLength ?? (18 * 1024 * 1024);
      final List<int> bytes = [];

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        _downloadProgress = (bytes.length / totalBytes).clamp(0.0, 0.90);
        yield _downloadProgress;
      }

      // Extraction phase (90% - 100%)
      yield 0.92;
      final archive = ZipDecoder().decodeBytes(bytes);
      final targetDir = await modelsDirectory;

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          final outFile = File('${targetDir.path}/$filename');
          outFile.parent.createSync(recursive: true);
          await outFile.writeAsBytes(data, flush: true);
        }
      }

      _downloadProgress = 1.0;
      yield 1.0;
    } catch (e) {
      debugPrint('Error downloading tier models: $e');
      rethrow;
    } finally {
      _isDownloading = false;
    }
  }
}
