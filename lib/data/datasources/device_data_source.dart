import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:carrier_info/carrier_info.dart';
import 'package:device_apps/device_apps.dart';
import '../../domain/entities/app_info_entity.dart';
import '../../services/device_id_service.dart';

class DeviceDataSource {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<Map<String, dynamic>> getDeviceInfo() async {
    final String uniqueId = await DeviceIdService.getDeviceId();

    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
      return {
        'manufacturer': androidInfo.manufacturer,
        'brand': androidInfo.brand,
        'model': androidInfo.model,
        'systemVersion': androidInfo.version.release,
        'sdkVersion': androidInfo.version.sdkInt.toString(),
        'deviceId': uniqueId,
        'hardware': androidInfo.hardware,
        'host': androidInfo.host,
        'board': androidInfo.board,
        'isPhysicalDevice': androidInfo.isPhysicalDevice,
        'platform': 'Android',
      };
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await _deviceInfo.iosInfo;
      return {
        'manufacturer': 'Apple',
        'brand': 'Apple',
        'model': iosInfo.model,
        'systemVersion': iosInfo.systemVersion,
        'sdkVersion': '未知',
        'deviceId': uniqueId,
        'hardware': iosInfo.utsname.machine,
        'host': iosInfo.utsname.nodename,
        'board': '未知',
        'isPhysicalDevice': iosInfo.isPhysicalDevice,
        'platform': 'iOS',
      };
    }
    return {};
  }

  Future<Map<String, dynamic>> getSimInfo() async {
    IosCarrierData? iosInfo;
    AndroidCarrierData? androidInfo;

    if (Platform.isAndroid) {
      androidInfo = await CarrierInfo.getAndroidInfo();
    } else if (Platform.isIOS) {
      iosInfo = await CarrierInfo.getIosInfo();
    }

    return {
      'operatorName': androidInfo?.telephonyInfo.firstOrNull?.carrierName ??
          iosInfo?.carrierData.firstOrNull?.carrierName,
      'isoCountryCode': androidInfo?.telephonyInfo.firstOrNull?.isoCountryCode ??
          iosInfo?.carrierData.firstOrNull?.isoCountryCode,
      'mobileNetworkCode':
          androidInfo?.telephonyInfo.firstOrNull?.mobileNetworkCode ??
              iosInfo?.carrierData.firstOrNull?.mobileNetworkCode,
      'mobileCountryCode':
          androidInfo?.telephonyInfo.firstOrNull?.mobileCountryCode ??
              iosInfo?.carrierData.firstOrNull?.mobileCountryCode,
      'phoneNumber': androidInfo?.subscriptionsInfo.firstOrNull?.phoneNumber,
      'platform': Platform.isAndroid ? 'Android' : 'iOS',
    };
  }

  Future<List<AppInfoEntity>> getInstalledApps() async {
    if (!Platform.isAndroid) return [];

    List<Application> apps = await DeviceApps.getInstalledApplications(
      includeSystemApps: true,
      includeAppIcons: false,
      onlyAppsWithLaunchIntent: false,
    );

    return apps.map((app) => AppInfoEntity(
      appName: app.appName,
      packageName: app.packageName,
      versionName: app.versionName ?? '',
      versionCode: app.versionCode,
      systemApp: app.systemApp,
      installTime: app.installTimeMillis,
      updateTime: app.updateTimeMillis,
      enabled: app.enabled,
      category: app.category.toString(),
    )).toList().cast<AppInfoEntity>();
  }
}
