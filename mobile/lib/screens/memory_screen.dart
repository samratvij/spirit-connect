import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../providers/memory_provider.dart';

class MemoryScreen extends ConsumerStatefulWidget {
  const MemoryScreen({super.key});

  @override
  ConsumerState<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends ConsumerState<MemoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(memoryProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(memoryProvider);

    ref.listen<MemoryState>(memoryProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.red.shade800,
          ),
        );
        ref.read(memoryProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0E1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: Text(
          'Memories',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF8B949E)),
            onPressed: () => ref.read(memoryProvider.notifier).load(),
          ),
        ],
      ),
      body: Builder(
        builder: (_) {
          if (state.status == MemoryStatus.loading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            );
          }

          if (state.memories.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.memory_outlined, size: 56, color: Color(0xFF30363D)),
                  const SizedBox(height: 16),
                  Text(
                    'No memories yet',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF8B949E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start chatting — Spirit will\nlearn from your conversations.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF484F58),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: state.memories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final memory = state.memories[i];
              return _MemoryTile(
                content: memory.content,
                date: memory.updatedAt,
                onDelete: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: const Color(0xFF161B22),
                      title: const Text('Delete memory?',
                          style: TextStyle(color: Colors.white)),
                      content: Text(
                        '"${memory.content}"',
                        style: const TextStyle(
                            color: Color(0xFF8B949E), fontStyle: FontStyle.italic),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete',
                              style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    ref.read(memoryProvider.notifier).delete(memory.id);
                  }
                },
                onEdit: () async {
                  final edited = await showDialog<String>(
                    context: context,
                    builder: (_) => _EditMemoryDialog(initial: memory.content),
                  );
                  if (edited != null && edited.trim().isNotEmpty) {
                    ref.read(memoryProvider.notifier).update(memory.id, edited.trim());
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _MemoryTile extends StatelessWidget {
  final String content;
  final DateTime date;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _MemoryTile({
    required this.content,
    required this.date,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha:0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.lightbulb_outline,
              size: 18, color: Color(0xFF6366F1)),
        ),
        title: Text(
          content,
          style: GoogleFonts.inter(fontSize: 14, color: Colors.white, height: 1.4),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            DateFormat('MMM d, yyyy').format(date.toLocal()),
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF484F58)),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF8B949E)),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF8B949E)),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _EditMemoryDialog extends StatefulWidget {
  final String initial;
  const _EditMemoryDialog({required this.initial});

  @override
  State<_EditMemoryDialog> createState() => _EditMemoryDialogState();
}

class _EditMemoryDialogState extends State<_EditMemoryDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF161B22),
      title: const Text('Edit Memory', style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: _controller,
        maxLines: 4,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFF0E1117),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF30363D)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF30363D)),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
