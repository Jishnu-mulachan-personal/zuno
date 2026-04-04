import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/encryption_service.dart';
import 'core/notification_service.dart';
import 'app_theme.dart';
import 'router.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  await dotenv.load(fileName: ".env");
  
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    debug: kDebugMode,
  );

  EncryptionService.init();
  await NotificationService().init();
  
  runApp(const ProviderScope(child: ZunoApp()));
}

class ZunoApp extends ConsumerWidget {
  const ZunoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Zuno',
      theme: ZunoTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
