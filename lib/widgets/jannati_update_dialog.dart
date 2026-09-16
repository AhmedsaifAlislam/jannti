import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_version_info.dart';
import 'jannati_logo.dart';

class JannatiUpdateDialog extends StatelessWidget {
  final AppVersionInfo versionInfo;
  final VoidCallback onUpdate;

  const JannatiUpdateDialog({
    super.key,
    required this.versionInfo,
    required this.onUpdate,
  });

  static Future<void> show({
    required BuildContext context,
    required AppVersionInfo versionInfo,
    required VoidCallback onUpdate,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: !versionInfo.forceUpdate,
      builder: (ctx) => JannatiUpdateDialog(
        versionInfo: versionInfo,
        onUpdate: onUpdate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: !versionInfo.forceUpdate,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0D2818),
                  Color(0xFF03140C),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Logo with subtle glow
                const Center(
                  child: JannatiLogo(size: 72, showGlow: true),
                ),
                const SizedBox(height: 16),

                // Title
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFFFFF9C4),
                      Color(0xFFFFD700),
                      Color(0xFFFFA000),
                    ],
                  ).createShader(bounds),
                  child: Text(
                    versionInfo.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Version Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'الإصدار الجديد: v${versionInfo.versionName}',
                    style: const TextStyle(
                      fontFamily: 'GESSTwo',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFD700),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Release Notes
                if (versionInfo.releaseNotes.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'ما الجديد في هذا الإصدار المبارك:',
                      style: TextStyle(
                        fontFamily: 'GESSTwo',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: versionInfo.releaseNotes.map((note) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '🌿 ',
                                  style: TextStyle(fontSize: 12),
                                ),
                                Expanded(
                                  child: Text(
                                    note,
                                    style: const TextStyle(
                                      fontFamily: 'GESSTwo',
                                      fontSize: 12,
                                      height: 1.4,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Action Buttons
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      onUpdate();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: const Color(0xFF03140C),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 6,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.download_rounded, size: 20, color: Color(0xFF03140C)),
                        SizedBox(width: 8),
                        Text(
                          'تحميل وتثبيت التحديث الآن ⚡',
                          style: TextStyle(
                            fontFamily: 'GESSTwo',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF03140C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (!versionInfo.forceUpdate) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'تذكيري لاحقاً',
                      style: TextStyle(
                        fontFamily: 'GESSTwo',
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
