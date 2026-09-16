class AppVersionInfo {
  final String versionName;
  final int versionCode;
  final int minSupportedVersionCode;
  final String title;
  final List<String> releaseNotes;
  final String apkUrl;
  final String? webUrl;
  final bool forceUpdate;

  const AppVersionInfo({
    required this.versionName,
    required this.versionCode,
    required this.minSupportedVersionCode,
    required this.title,
    required this.releaseNotes,
    required this.apkUrl,
    this.webUrl,
    this.forceUpdate = false,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      versionName: json['version_name']?.toString() ?? '1.0.0',
      versionCode: json['version_code'] is int
          ? json['version_code'] as int
          : int.tryParse(json['version_code']?.toString() ?? '1') ?? 1,
      minSupportedVersionCode: json['min_supported_version_code'] is int
          ? json['min_supported_version_code'] as int
          : int.tryParse(json['min_supported_version_code']?.toString() ?? '1') ?? 1,
      title: json['title']?.toString() ?? 'تحديث جديد مبارك لـ جنّتي ✨',
      releaseNotes: (json['release_notes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      apkUrl: json['apk_url']?.toString() ?? '',
      webUrl: json['web_url']?.toString(),
      forceUpdate: json['force_update'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version_name': versionName,
      'version_code': versionCode,
      'min_supported_version_code': minSupportedVersionCode,
      'title': title,
      'release_notes': releaseNotes,
      'apk_url': apkUrl,
      'web_url': webUrl,
      'force_update': forceUpdate,
    };
  }
}
