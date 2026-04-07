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
import 'core/version_service.dart';
import 'shared/widgets/update_dialog.dart';
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

  final container = ProviderContainer();
  await NotificationService().init(container);
  
  runApp(UncontrolledProviderScope(
    container: container,
    child: const ZunoApp(),
  ));
}

class ZunoApp extends ConsumerStatefulWidget {
  const ZunoApp({super.key});

  @override
  ConsumerState<ZunoApp> createState() => _ZunoAppState();
}

class _ZunoAppState extends ConsumerState<ZunoApp> {
  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Zuno',
      theme: ZunoTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return _UpdateChecker(child: child ?? const SizedBox.shrink());
      },
    );
  }
}

class _UpdateChecker extends ConsumerStatefulWidget {
  final Widget child;
  const _UpdateChecker({required this.child});

  @override
  ConsumerState<_UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends ConsumerState<_UpdateChecker> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdates());
  }

  Future<void> _checkForUpdates() async {
    final versionService = VersionService();
    
    final currentVersion = await versionService.getCurrentVersion();
    final latestInfo = await versionService.getLatestVersionInfo();

    if (latestInfo == null) return;

    final hasUpdate = versionService.isUpdateAvailable(currentVersion, latestInfo.latestVersion);
    
    if (hasUpdate) {
      final shouldPrompt = await versionService.shouldShowReminder();
      
      if (shouldPrompt && mounted) {
        final navContext = rootNavigatorKey.currentContext;
        if (navContext != null && navContext.mounted) {
          showDialog(
            context: navContext,
            barrierDismissible: false,
            builder: (context) => UpdateDialog(
              latestVersion: latestInfo.latestVersion,
              updateUrl: latestInfo.updateUrl,
              releaseNotes: latestInfo.releaseNotes ?? "New features and improvements await!",
              onRemindLater: () => versionService.markRemindLater(),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
