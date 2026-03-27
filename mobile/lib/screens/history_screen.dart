import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../providers/history_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/persona_provider.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(historyProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyProvider);
    final personas = ref.watch(personasProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0E1117),
      appBar: AppBar(
        title: Text('History', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(historyProvider.notifier).load(),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.conversations.isEmpty
              ? _EmptyHistory()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.conversations.length,
                  itemBuilder: (context, index) {
                    final conv = state.conversations[index];
                    final persona = personas.firstWhere(
                      (p) => p.modelName == conv.personaId,
                      orElse: () => personas.first,
                    );

                    return Card(
                      color: const Color(0xFF161B22),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFF30363D)),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF0E1117),
                          child: Text(persona.icon),
                        ),
                        title: Text(
                          conv.title ?? 'Conversation ${conv.id}',
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          '${persona.name} • ${DateFormat('MMM d, h:mm a').format(conv.updatedAt)}',
                          style: GoogleFonts.inter(color: const Color(0xFF8B949E), fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Color(0xFF484F58)),
                        onTap: () async {
                          await ref.read(chatProvider.notifier).loadConversation(conv.id);
                          ref.read(selectedPersonaProvider.notifier).state = persona;
                          ref.read(selectedTabProvider.notifier).state = 1; // Switch to Chat tab
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history, size: 64, color: Color(0xFF30363D)),
          const SizedBox(height: 16),
          Text(
            'No history yet',
            style: GoogleFonts.inter(color: const Color(0xFF8B949E), fontSize: 16),
          ),
        ],
      ),
    );
  }
}
