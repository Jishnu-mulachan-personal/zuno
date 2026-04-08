import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../app_theme.dart';
import '../../core/theme_provider.dart';
import 'dashboard_state.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    final state = ref.read(dashboardProvider);
    final insight = state.dailyInsight ?? 'No insight today.';
    final sbUser = Supabase.instance.client.auth.currentUser;
    final identifier = sbUser?.email;

    if (identifier == null) {
      setState(() {
        _messages.add({'role': 'error', 'content': 'You must be logged in.'});
        _isLoading = false;
      });
      return;
    }

    // Recent context handled server-side now
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'chat_with_insight',
        body: {
          'identifier': identifier,
          'message': text,
          'dailyInsight': insight,
          'chatHistory': _messages.where((m) => m['role'] != 'error').toList(),
        },
      );
      
      final reply = response.data['reply'] as String?;
      if (reply != null) {
        setState(() {
          _messages.add({'role': 'ai', 'content': reply});
        });
      }
    } catch (e) {
      debugPrint('[chat_with_insight] Error: $e');
      setState(() {
        _messages.add({'role': 'error', 'content': 'Could not connect to Zuno AI.'});
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch theme changes to trigger rebuild
    ref.watch(themeProvider);
    return Scaffold(
      backgroundColor: ZunoTheme.surface,
      appBar: AppBar(
        backgroundColor: ZunoTheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: BackButton(
          color: ZunoTheme.primary,
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Zuno AI',
          style: GoogleFonts.notoSerif(
            color: ZunoTheme.primary,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ZunoTheme.primary,
                        ),
                      ),
                    ),
                  );
                }

                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                final isError = msg['role'] == 'error';

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.8,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? ZunoTheme.primary
                          : (isError ? ZunoTheme.error.withOpacity(0.08) : ZunoTheme.surfaceContainerHigh),
                      borderRadius: BorderRadius.circular(24).copyWith(
                        bottomRight: isUser ? const Radius.circular(4) : null,
                        bottomLeft: !isUser ? const Radius.circular(4) : null,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Text(
                      msg['content'] ?? '',
                      style: GoogleFonts.plusJakartaSans(
                        color: isUser
                            ? Colors.white
                            : (isError ? ZunoTheme.error : ZunoTheme.onSurface),
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 40, top: 20),
            decoration: BoxDecoration(
              color: ZunoTheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _sendMessage(),
                    style: GoogleFonts.plusJakartaSans(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Ask Zuno anything...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        color: ZunoTheme.onSurfaceVariant.withOpacity(0.5),
                        fontSize: 15,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: ZunoTheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: ZunoTheme.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

