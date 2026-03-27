import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flattened_node.dart';

import '../models/ui_state.dart';
import '../services/file_service.dart';
import '../state/outliner_state.dart';
import 'outliner_notifier.dart';
import 'ui_state_notifier.dart';

// ─── Service Providers ───────────────────────────────────────────────

final fileServiceProvider = Provider<FileService>((ref) => FileService());

// ─── State Providers ─────────────────────────────────────────────────

final outlinerProvider =
    NotifierProvider<OutlinerNotifier, OutlinerInMemoryState>(
  OutlinerNotifier.new,
);

final uiStateProvider =
    NotifierProvider<UIStateNotifier, OutlinerUIState>(
  UIStateNotifier.new,
);

// ─── Focus Tracking ──────────────────────────────────────────────────

final focusedNodeIdProvider = NotifierProvider<FocusedNodeNotifier, String?>(FocusedNodeNotifier.new);

class FocusedNodeNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? nodeId) {
    state = nodeId;
  }
}

class FocusJumpRequest {
  final int column;
  final bool isDown;
  const FocusJumpRequest({required this.column, required this.isDown});
}

class FocusJumpNotifier extends Notifier<FocusJumpRequest?> {
  @override
  FocusJumpRequest? build() => null;
  
  void set(FocusJumpRequest? req) {
    state = req;
  }
}

final focusJumpProvider = NotifierProvider<FocusJumpNotifier, FocusJumpRequest?>(FocusJumpNotifier.new);

// ─── Derived Providers ───────────────────────────────────────────────

/// Flattened list of visible nodes for the ListView.
/// Built via DFS traversal, skipping children of folded nodes.
final flattenedListProvider = Provider<List<FlattenedNode>>((ref) {
  final outlinerState = ref.watch(outlinerProvider);
  final uiState = ref.watch(uiStateProvider);

  return _buildFlattenedList(outlinerState, uiState.foldedNodes);
});

/// Build a flattened, depth-annotated list of visible nodes via DFS.
List<FlattenedNode> _buildFlattenedList(
  OutlinerInMemoryState state,
  Set<String> foldedNodes,
) {
  final result = <FlattenedNode>[];

  void dfs(String? parentId, int depth) {
    final childrenIds = state.getChildrenIds(parentId);
    for (final childId in childrenIds) {
      final node = state.nodesMap[childId];
      if (node == null) continue;

      final hasChildren = state.hasChildren(childId);
      final isFolded = foldedNodes.contains(childId);

      result.add(FlattenedNode(
        node: node,
        depth: depth,
        hasChildren: hasChildren,
        isFolded: isFolded,
      ));

      // Only recurse into children if not folded
      if (!isFolded && hasChildren) {
        dfs(childId, depth + 1);
      }
    }
  }

  dfs(null, 0);
  return result;
}
