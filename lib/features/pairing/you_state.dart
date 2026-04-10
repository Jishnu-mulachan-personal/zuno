import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/encryption_service.dart';

class DailyLog {
  final String date;
  final String createdTime;
  final String moodEmoji;
  final bool connectionFelt;
  final List<String> contextTags;
  final String? journalNote;
  final bool shareWithPartner;

  DailyLog({
    required this.date,
    required this.createdTime,
    required this.moodEmoji,
    required this.connectionFelt,
    required this.contextTags,
    this.journalNote,
    this.shareWithPartner = false,
  });
}

final userLogsProvider = FutureProvider<List<DailyLog>>((ref) async {
  final sbUser = Supabase.instance.client.auth.currentUser;
  if (sbUser == null) return [];

  final userId = sbUser.id;
  final supabase = Supabase.instance.client;
  
  final response = await supabase
      .from('daily_logs')
      .select()
      .eq('user_id', userId)
      .order('created_at', ascending: false);

  if (response is! List) return [];
  
  return response.map((row) {
    String? noteStr;
    if (row['journal_note'] != null) {
      try {
        final dynamic jn = row['journal_note'];
        // Debug: print the raw type and value from Supabase
        debugPrint('[you_state] journal_note runtimeType=${jn.runtimeType}, value=$jn');

        if (jn is List) {
          // Direct list of ints — decrypt or char codes
          final bytes = List<int>.from(jn);
          noteStr = EncryptionService.decrypt(bytes);
        } else if (jn is String) {
          if (jn.startsWith('\\x')) {
            // Postgres BYTEA hex: \x<hex> — decode hex to ASCII string first
            final hexStr = jn.substring(2);
            final asciiBytes = <int>[];
            for (int i = 0; i < hexStr.length; i += 2) {
              asciiBytes.add(int.parse(hexStr.substring(i, i + 2), radix: 16));
            }
            // The ASCII bytes represent a JSON array string like "[119,97,116,...]"
            final inner = String.fromCharCodes(asciiBytes);
            if (inner.startsWith('[')) {
              final stripped = inner.substring(1, inner.length - 1).trim();
              if (stripped.isNotEmpty) {
                final parsedBytes = stripped.split(',').map((e) => int.parse(e.trim())).toList();
                // Try Fernet decryption first (new records). Fall back to charCodes (old plain records).
                try {
                  noteStr = EncryptionService.decrypt(parsedBytes);
                } catch (_) {
                  noteStr = String.fromCharCodes(parsedBytes);
                }
              }
            } else {
              noteStr = EncryptionService.decrypt(asciiBytes);
            }
          } else if (jn.startsWith('[')) {
            // Stringified int array directly
            final stripped = jn.substring(1, jn.length - 1).trim();
            if (stripped.isNotEmpty) {
              final codeUnits = stripped.split(',').map((e) => int.parse(e.trim())).toList();
              noteStr = String.fromCharCodes(codeUnits);
            }
          } else {
            noteStr = jn; // plain text fallback
          }
        }
      } catch (e) {
        debugPrint('[you_state] journal_note decode error: $e');
        noteStr = null;
      }
    }
    
    DateTime? createdTime;
    if (row['created_at'] != null) {
      createdTime = DateTime.tryParse(row['created_at'].toString())?.toLocal();
    }
    String timeStr = '';
    if (createdTime != null) {
      timeStr = '${createdTime.hour.toString().padLeft(2, '0')}:${createdTime.minute.toString().padLeft(2, '0')}';
    }
    
    return DailyLog(
      date: row['log_date'] as String? ?? '',
      createdTime: timeStr,
      moodEmoji: row['mood_emoji'] as String? ?? '😊',
      connectionFelt: row['connection_felt'] as bool? ?? true,
      contextTags: List<String>.from(row['context_tags'] ?? []),
      journalNote: noteStr,
      shareWithPartner: row['share_with_partner'] as bool? ?? false,
    );
  }).toList();
});
