import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'url_launcher_stub.dart'
    if (dart.library.html) 'url_launcher_web.dart';

import '../models/app_version_info.dart';
import '../widgets/jannati_update_dialog.dart';

class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  static const int currentVersionCode = 1;
  static const String currentVersionName = '1.0.0';

  // 🌐 Default remote configuration endpoint
  // مربوط بمستودعك على GitHub
  static String updateConfigUrl =
      'https://raw.githubusercontent.com/AhmedsaifAlislam/jannti/main/version.json';

  static const MethodChannel _channel = MethodChannel('com.example.jannti/audio');

  bool _isChecking = false;
  bool get isChecking => _isChecking;

  /// Fetches remote version info from [updateConfigUrl]
  Future<AppVersionInfo?> fetchRemoteVersion() async {
    try {
      final uri = Uri.parse(updateConfigUrl);
      final response = await http.get(uri).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data is Map<String, dynamic>) {
          return AppVersionInfo.fromJson(data);
        }
      }
    } catch (e) {
      debugPrint('ℹ️ Update check network note: $e');
    }
    return null;
  }

  /// Checks for updates and displays the luxury dialog if an update is available.
  /// If [isManual] is true, it displays feedback SnackBar if already up to date or failed.
  Future<void> checkAndPromptUpdate(
    BuildContext context, {
    bool isManual = false,
  }) async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      if (isManual) {
        _showSnackBar(
          context,
          'جارٍ التحقق من وجود تحديثات مباركة... ⏳',
          isGold: false,
        );
      }

      final remoteInfo = await fetchRemoteVersion();

      if (!context.mounted) return;

      if (remoteInfo == null) {
        if (isManual) {
          _showSnackBar(
            context,
            'تعذر التحقق من التحديثات، تأكد من اتصال الإنترنت 📶',
            isGold: false,
          );
        }
        return;
      }

      // Check if remote version is newer
      if (remoteInfo.versionCode > currentVersionCode) {
        await JannatiUpdateDialog.show(
          context: context,
          versionInfo: remoteInfo,
          onUpdate: () => openDownloadUrl(remoteInfo.apkUrl),
        );
      } else {
        if (isManual) {
          _showSnackBar(
            context,
            'أنت تستخدم أحدث إصدار مبارك من جنّتي (v$currentVersionName) 🌿✨',
            isGold: true,
          );
        }
      }
    } finally {
      _isChecking = false;
    }
  }

  /// Opens the APK download URL or release page
  Future<void> openDownloadUrl(String url) async {
    if (url.isEmpty) return;

    try {
      if (kIsWeb) {
        launchWebUrl(url);
      } else {
        await _channel.invokeMethod('openUrl', {'url': url});
      }
      debugPrint('🚀 Opened update URL: $url');
    } catch (e) {
      debugPrint('⚠️ Error launching update URL: $e');
    }
  }

  void _showSnackBar(BuildContext context, String message, {bool isGold = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: 'GESSTwo',
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isGold ? const Color(0xFFFFD700) : Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF0D2818),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isGold ? const Color(0xFFFFD700) : Colors.white24,
            width: 1.2,
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
