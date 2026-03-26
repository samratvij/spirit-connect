import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/memory.dart';
import '../services/api_service.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum MemoryStatus { idle, loading, success, error }

class MemoryState {
  final List<MemoryRecord> memories;
  final MemoryStatus status;
  final String? error;

  const MemoryState({
    this.memories = const [],
    this.status = MemoryStatus.idle,
    this.error,
  });

  MemoryState copyWith({
    List<MemoryRecord>? memories,
    MemoryStatus? status,
    String? error,
  }) {
    return MemoryState(
      memories: memories ?? this.memories,
      status: status ?? this.status,
      error: error,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class MemoryNotifier extends StateNotifier<MemoryState> {
  MemoryNotifier() : super(const MemoryState());

  Future<void> load() async {
    state = state.copyWith(status: MemoryStatus.loading, error: null);
    try {
      final memories = await apiService.fetchMemories();
      state = state.copyWith(memories: memories, status: MemoryStatus.success);
    } catch (e) {
      state = state.copyWith(
        status: MemoryStatus.error,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> delete(int id) async {
    try {
      await apiService.deleteMemory(id);
      state = state.copyWith(
        memories: state.memories.where((m) => m.id != id).toList(),
      );
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to delete: ${e.toString()}',
      );
    }
  }

  Future<void> update(int id, String content) async {
    try {
      final updated = await apiService.updateMemory(id, content);
      state = state.copyWith(
        memories: state.memories.map((m) => m.id == id ? updated : m).toList(),
      );
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to update: ${e.toString()}',
      );
    }
  }

  void clearError() => state = state.copyWith(error: null);
}

final memoryProvider = StateNotifierProvider<MemoryNotifier, MemoryState>(
  (ref) => MemoryNotifier(),
);
