import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'splash_page.dart';
import 'core/config/app_config.dart';
import 'core/di/service_locator.dart';
import 'presentation/providers/sync_provider.dart';
import 'domain/usecases/sync_data_use_case.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  await setupServiceLocator();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SyncProvider(getIt<SyncDataUseCase>()),
        ),
      ],
      child: MaterialApp(
        title: '乐盈',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6A11CB),
            primary: const Color(0xFF6A11CB),
            secondary: const Color(0xFF2575FC),
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
          fontFamily: 'Roboto',
        ),
        home: const SplashPage(),
      ),
    );
  }
}
