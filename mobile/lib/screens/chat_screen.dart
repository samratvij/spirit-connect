import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';

import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../providers/persona_provider.dart';
import '../models/persona.dart';
import '../providers/history_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _userHasScrolledUp = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-fetch conversation to sync any background progress from the server
      final chatState = ref.read(chatProvider);
      if (chatState.activeConversationId != null) {
        ref.read(chatProvider.notifier).loadConversation(chatState.activeConversationId!);
      }
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final pos = _scrollController.position;
      // If user is more than 30 pixels from the bottom, they are "scrolled up"
      final isAtBottom = pos.pixels >= pos.maxScrollExtent - 30;
      if (!isAtBottom && !_userHasScrolledUp) {
        setState(() => _userHasScrolledUp = true);
      } else if (isAtBottom && _userHasScrolledUp) {
        setState(() => _userHasScrolledUp = false);
      }
    }
  }

  void _scrollToBottom({bool force = false}) {
    if (_userHasScrolledUp && !force) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _focusNode.requestFocus();
    
    var state = ref.read(chatProvider);
    final selectedPersona = ref.read(selectedPersonaProvider);

    // 1. Create conversation if none exists
    if (state.activeConversationId == null) {
      final conv = await ref.read(historyProvider.notifier).create(
        selectedPersona.modelName ?? 'spirit',
        text.length > 30 ? '${text.substring(0, 30)}...' : text,
      );
      ref.read(chatProvider.notifier).startNewChat(conv.id);
    }

    // 2. Send message
    await ref.read(chatProvider.notifier).sendMessage(
      text, 
      model: selectedPersona.modelName,
    );
    _scrollToBottom(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);
    final isNewChat = state.messages.isEmpty && state.activeConversationId == null;

    // Show errors as snackbar
    ref.listen<ChatState>(chatProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
      if (next.messages.length != prev?.messages.length ||
          (next.messages.isNotEmpty && next.messages.last.isStreaming)) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0E1117),
      drawer: const _HistoryDrawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF8B949E)),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          isNewChat ? 'New Chat' : 'Spirit Connect',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'New Chat',
            onPressed: () {
              ref.read(chatProvider.notifier).startNewChat(null);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (isNewChat) const _NewChatPersonaGrid() else const SizedBox.shrink(),
          Expanded(
            child: state.messages.isEmpty && !state.isLoading
                ? (isNewChat ? const SizedBox.shrink() : _EmptyState())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: state.messages.length,
                    itemBuilder: (ctx, i) => _MessageBubble(message: state.messages[i]),
                  ),
          ),
          _InputBar(
            controller: _controller,
            focusNode: _focusNode,
            isLoading: state.isLoading,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

class _NewChatPersonaGrid extends ConsumerWidget {
  const _NewChatPersonaGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personas = ref.watch(personasProvider);
    final selected = ref.watch(selectedPersonaProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose a Persona',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF8B949E),
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
            ),
            itemCount: personas.length,
            itemBuilder: (context, index) {
              final persona = personas[index];
              final isSelected = persona.id == selected.id;

              return GestureDetector(
                onTap: () => ref.read(selectedPersonaProvider.notifier).state = persona,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF6366F1).withValues(alpha:0.1) : const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF30363D),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(persona.icon, style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 8),
                      Text(
                        persona.name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF8B949E),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha:0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome, size: 32, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text(
            'Hello, I\'m Spirit',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your private AI assistant.\nEverything stays on your device.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF8B949E),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends ConsumerWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: 10, top: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isUser) 
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      ref.read(selectedPersonaProvider).name,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF8B949E),
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFF6366F1) : const Color(0xFF161B22),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: isUser ? const Radius.circular(18) : const Radius.circular(4),
                      bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(18),
                    ),
                    border: isUser
                        ? null
                        : Border.all(color: const Color(0xFF30363D), width: 1),
                    boxShadow: isUser
                        ? [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withValues(alpha:0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: message.isStreaming && message.content.isEmpty
                      ? _TypingIndicator()
                      : Text(
                          message.content,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: Colors.white,
                            height: 1.5,
                          ),
                        ),
                ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i / 3;
            final opacity = ((_controller.value - delay) % 1.0).abs();
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:0.3 + opacity * 0.7),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

class _InputBar extends ConsumerWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(chatProvider).pendingAttachments;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(top: BorderSide(color: Color(0xFF30363D), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            if (pending.isNotEmpty) _AttachmentPreview(paths: pending),
            Padding(
              padding: EdgeInsets.only(
                left: 8,
                right: 12,
                top: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom + 8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Color(0xFF8B949E)),
                    onPressed: isLoading ? null : () async {
                      final result = await FilePicker.platform.pickFiles(
                        allowMultiple: true,
                        type: FileType.any,
                      );
                      if (result != null && result.paths.isNotEmpty) {
                        for (final path in result.paths) {
                          if (path != null) {
                            ref.read(chatProvider.notifier).addAttachment(path);
                          }
                        }
                      }
                    },
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E1117),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFF30363D)),
                      ),
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        enabled: !isLoading,
                        maxLines: 6,
                        minLines: 1,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Message Spirit...',
                          hintStyle: const TextStyle(color: Color(0xFF484F58)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => onSend(),
                        textInputAction: TextInputAction.send,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: isLoading
                          ? const LinearGradient(
                              colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                            )
                          : const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            ),
                      borderRadius: BorderRadius.circular(21),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(21),
                        onTap: isLoading 
                            ? () => ref.read(chatProvider.notifier).stopResponse()
                            : onSend,
                        child: Center(
                          child: isLoading
                              ? const Icon(Icons.stop_circle_rounded, color: Colors.white, size: 24)
                              : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentPreview extends ConsumerWidget {
  final List<String> paths;
  const _AttachmentPreview({required this.paths});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF21262D))),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: paths.length,
        itemBuilder: (ctx, i) {
          final path = paths[i];
          final fileName = path.split('/').last;
          final isImage = path.toLowerCase().endsWith('.jpg') || 
                          path.toLowerCase().endsWith('.png') || 
                          path.toLowerCase().endsWith('.jpeg');

          return Container(
            width: 70,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: Stack(
              children: [
                Center(
                  child: isImage 
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(path), fit: BoxFit.cover, width: 70, height: 70),
                      )
                    : const Icon(Icons.insert_drive_file, color: Color(0xFF8B949E)),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 14, color: Colors.white),
                    onPressed: () => ref.read(chatProvider.notifier).removeAttachment(path),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HistoryDrawer extends ConsumerWidget {
  const _HistoryDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final personas = ref.watch(personasProvider);

    return Drawer(
      backgroundColor: const Color(0xFF0E1117),
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              border: Border(bottom: BorderSide(color: Color(0xFF30363D))),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history, size: 40, color: Color(0xFF6366F1)),
                  const SizedBox(height: 12),
                  Text(
                    'Chat History',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: history.isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: history.conversations.length,
                    itemBuilder: (context, index) {
                      final conv = history.conversations[index];
                      final persona = personas.firstWhere(
                        (p) => p.modelName == conv.personaId,
                        orElse: () => personas.first,
                      );

                      return ListTile(
                        leading: Text(persona.icon, style: const TextStyle(fontSize: 20)),
                        title: Text(
                          conv.title ?? 'Untitled Chat',
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          persona.name,
                          style: GoogleFonts.inter(color: const Color(0xFF8B949E), fontSize: 11),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF484F58)),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: const Color(0xFF161B22),
                                title: const Text('Delete chat?', style: TextStyle(color: Colors.white)),
                                content: const Text('This will permanently remove the conversation.', style: TextStyle(color: Color(0xFF8B949E))),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              ref.read(historyProvider.notifier).delete(conv.id);
                            }
                          },
                        ),
                        onTap: () async {
                          Navigator.pop(context); // Close drawer
                          await ref.read(chatProvider.notifier).loadConversation(conv.id);
                          ref.read(selectedPersonaProvider.notifier).state = persona;
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

