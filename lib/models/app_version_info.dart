class AppVersionInfo {
  final String versionName;
  final int versionCode;
  final int minSupportedVersionCode;
  final String title;
  final List<String> releaseNotes;
  final String apkUrl;
  final String? webUrl;
  final bool forceUpdate;

  // 👥 عدد المستخدمين النشطين (Social Proof) - مهيأ عن بُعد عبر version.json
  final int? activeUsersBase;
  final bool activeUsersEnabled;
  final int activeUsersGrowthPerDay;

  const AppVersionInfo({
    required this.versionName,
    required this.versionCode,
    required this.minSupportedVersionCode,
    required this.title,
    required this.releaseNotes,
    required this.apkUrl,
    this.webUrl,
    this.forceUpdate = false,
    this.activeUsersBase,
    this.activeUsersEnabled = true,
    this.activeUsersGrowthPerDay = 0,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      versionName: json['version_name']?.toString() ?? '1.0.0',
      versionCode: json['version_code'] is int
          ? json['version_code'] as int
          : int.tryParse(json['version_code']?.toString() ?? '1') ?? 1,
      minSupportedVersionCode: json['min_supported_version_code'] is int
          ? json['min_supported_version_code'] as int
          : int.tryParse(
                  json['min_supported_version_code']?.toString() ?? '1',
                ) ??
                1,
      title: json['title']?.toString() ?? 'تحديث جديد مبارك لـ جنّتي ✨',
      releaseNotes:
          (json['release_notes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      apkUrl: json['apk_url']?.toString() ?? '',
      webUrl: json['web_url']?.toString(),
      forceUpdate: json['force_update'] == true,
      activeUsersBase: json['active_users_base'] is int
          ? json['active_users_base'] as int
          : int.tryParse('${json['active_users_base']}'),
      activeUsersEnabled: json['active_users_enabled'] != false,
      activeUsersGrowthPerDay: json['active_users_growth_per_day'] is int
          ? json['active_users_growth_per_day'] as int
          : int.tryParse('${json['active_users_growth_per_day']}') ?? 0,
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
      'active_users_base': activeUsersBase,
      'active_users_enabled': activeUsersEnabled,
      'active_users_growth_per_day': activeUsersGrowthPerDay,
    };
  }
}
