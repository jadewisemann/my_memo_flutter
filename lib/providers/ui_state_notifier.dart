import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ui_state.dart';
import '../services/file_service.dart';
import 'providers.dart';

/// Riverpod Notifier managing UI-only state (fold, focus, scroll).
/// This state is persisted separately from content.
class UIStateNotifier extends Notifier<OutlinerUIState> {
  Timer? _saveTimer;

  @override
  OutlinerUIState build() {
    return const OutlinerUIState();
  }

  FileService get _fileService => ref.read(fileServiceProvider);

  /// Load UI state from disk.
  Future<void> loadFromDisk() async {
    state = await _fileService.loadUIState();
  }

  /// Toggle fold state of a node.
  void toggleFold(String nodeId) {
    final foldedNodes = Set<String>.from(state.foldedNodes);
    if (foldedNodes.contains(nodeId)) {
      foldedNodes.remove(nodeId);
    } else {
      foldedNodes.add(nodeId);
    }
    state = state.copyWith(foldedNodes: foldedNodes);
    _scheduleSave();
  }

  /// Set the last active (focused) node.
  void setActiveNode(String? nodeId) {
    state = state.copyWith(lastActiveNodeId: () => nodeId);
    _scheduleSave();
  }

  /// Update scroll position.
  void setScrollPosition(double offset) {
    state = state.copyWith(scrollPosition: offset);
    _scheduleSave();
  }

  /// Toggle positional vs logical outdent.
  void toggleOutdentMode() {
    state = state.copyWith(useLogicalOutdent: !state.useLogicalOutdent);
    _scheduleSave();
  }

  // ─── Selection Mode ──────────────────────────────────────────────────

  void toggleSelectionMode(String nodeId) {
    if (state.selectedNodeIds.contains(nodeId)) {
      clearSelection();
    } else {
      state = state.copyWith(
        selectedNodeIds: {nodeId},
        selectionAnchorId: () => nodeId,
      );
    }
  }

  void expandSelection(Set<String> newSelection) {
    state = state.copyWith(selectedNodeIds: newSelection);
  }

  void clearSelection() {
    if (state.selectedNodeIds.isNotEmpty) {
      state = state.copyWith(
        selectedNodeIds: const {},
        selectionAnchorId: () => null,
      );
    }
  }

  /// Check if a node is folded.
  bool isFolded(String nodeId) {
    return state.foldedNodes.contains(nodeId);
  }

  /// Schedule a debounced save for UI state.
  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 1000), () {
      _fileService.saveUIState(state);
    });
  }
}
