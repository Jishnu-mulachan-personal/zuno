import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class AppVersionInfo {
  final String latestVersion;
  final String minVersion;
  final String updateUrl;
  final String? releaseNotes;

  AppVersionInfo({
    required this.latestVersion,
    required this.minVersion,
    required this.updateUrl,
    this.releaseNotes,
  });

  factory AppVersionInfo.fromMap(Map<String, dynamic> map) {
    return AppVersionInfo(
      latestVersion: map['latest_version'] as String,
      minVersion: map['min_version'] as String,
      updateUrl: map['update_url'] as String,
      releaseNotes: map['release_notes'] as String?,
    );
  }
}

class VersionService {
  static const String _lastRemindedKey = 'last_update_remind_date';

  /// Returns the current app version (e.g., "1.0.0")
  Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  /// Fetches the latest version info from Supabase for the current platform
  Future<AppVersionInfo?> getLatestVersionInfo() async {
    try {
      final platform = Platform.isAndroid ? 'android' : 'ios';
      final supabase = Supabase.instance.client;
      
      final response = await supabase
          .from('app_versions')
          .select('*')
          .eq('platform', platform)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        return AppVersionInfo.fromMap(response);
      }
    } catch (e) {
      debugPrint('[VersionService] Error fetching latest version: $e');
    }
    return null;
  }

  /// Compares two version strings (e.g., "1.0.1" vs "1.0.0")
  /// Returns true if [latest] is newer than [current]
  bool isUpdateAvailable(String current, String latest) {
    final currentParts = current.split('.').map(int.parse).toList();
    final latestParts = latest.split('.').map(int.parse).toList();

    for (var i = 0; i < latestParts.length; i++) {
      final latestPart = latestParts[i];
      final currentPart = i < currentParts.length ? currentParts[i] : 0;
      if (latestPart > currentPart) return true;
      if (latestPart < currentPart) return false;
    }
    return false;
  }

  /// Checks if we should show the reminder dialog based on the last suppression
  Future<bool> shouldShowReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final lastReminded = prefs.getString(_lastRemindedKey);
    
    if (lastReminded == null) return true;

    final lastDate = DateTime.parse(lastReminded);
    final now = DateTime.now();
    
    // Remind again after 24 hours
    return now.difference(lastDate).inHours >= 24;
  }

  /// Saves today's date to suppress the reminder for 24 hours
  Future<void> markRemindLater() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastRemindedKey, DateTime.now().toIso8601String());
  }
}
