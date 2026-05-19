class AppInfoEntity {
  final String appName;
  final String packageName;
  final String versionName;
  final int versionCode;
  final bool systemApp;
  final int installTime;
  final int updateTime;
  final bool enabled;
  final String category;

  AppInfoEntity({
    required this.appName,
    required this.packageName,
    required this.versionName,
    required this.versionCode,
    required this.systemApp,
    required this.installTime,
    required this.updateTime,
    required this.enabled,
    required this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'appName': appName,
      'packageName': packageName,
      'versionName': versionName,
      'versionCode': versionCode,
      'systemApp': systemApp,
      'installTime': installTime,
      'updateTime': updateTime,
      'enabled': enabled,
      'category': category,
    };
  }
}
