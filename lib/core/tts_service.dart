import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TtsState {
  final bool isSpeaking;
  final String? currentText;

  TtsState({this.isSpeaking = false, this.currentText});

  TtsState copyWith({bool? isSpeaking, String? currentText}) {
    return TtsState(
      isSpeaking: isSpeaking ?? this.isSpeaking,
      currentText: currentText ?? this.currentText,
    );
  }
}

class TtsNotifier extends StateNotifier<TtsState> {
  final FlutterTts _flutterTts = FlutterTts();

  TtsNotifier() : super(TtsState()) {
    _init();
  }

  void _init() {
    _flutterTts.setStartHandler(() {
      debugPrint('[TtsService] Speech started');
      state = state.copyWith(isSpeaking: true);
    });

    _flutterTts.setCompletionHandler(() {
      debugPrint('[TtsService] Speech completed');
      state = state.copyWith(isSpeaking: false, currentText: null);
    });

    _flutterTts.setCancelHandler(() {
      debugPrint('[TtsService] Speech cancelled');
      state = state.copyWith(isSpeaking: false, currentText: null);
    });

    _flutterTts.setErrorHandler((msg) {
      debugPrint('[TtsService] Error: $msg');
      state = state.copyWith(isSpeaking: false, currentText: null);
    });
  }

  Future<void> speak(String text) async {
    // If already speaking the SAME text, stop it (toggle behavior)
    if (state.isSpeaking && state.currentText == text) {
      await stop();
      return;
    }

    // If speaking something else, stop it first
    if (state.isSpeaking) {
      await stop();
    }

    state = state.copyWith(currentText: text);
    
    try {
      // Basic configuration
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5); // Natural pace
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('[TtsService] Speak error: $e');
      state = state.copyWith(isSpeaking: false, currentText: null);
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      state = state.copyWith(isSpeaking: false, currentText: null);
    } catch (e) {
      debugPrint('[TtsService] Stop error: $e');
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }
}

final ttsProvider = StateNotifierProvider<TtsNotifier, TtsState>((ref) {
  return TtsNotifier();
});
