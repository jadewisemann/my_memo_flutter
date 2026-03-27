import '../models/outline_node.dart';

/// The core in-memory state container for the outliner.
/// Uses dual hash maps for O(1) lookup and manipulation.
class OutlinerInMemoryState {
  /// Master map for O(1) lookup by node ID.
  final Map<String, OutlineNode> nodesMap;

  /// Tree structure pointers: parentId → list of child IDs sorted by order.
  /// null key represents root-level nodes.
  final Map<String?, List<String>> childrenPointerMap;

  const OutlinerInMemoryState({
    this.nodesMap = const {},
    this.childrenPointerMap = const {},
  });

  /// Build the state from a flat list of nodes.
  factory OutlinerInMemoryState.fromNodes(List<OutlineNode> nodes) {
    final nodesMap = <String, OutlineNode>{};
    final childrenPointerMap = <String?, List<String>>{};

    for (final node in nodes) {
      nodesMap[node.id] = node;
      childrenPointerMap.putIfAbsent(node.parentId, () => []).add(node.id);
    }

    // Sort each children list by the node's order property
    for (final entry in childrenPointerMap.entries) {
      entry.value.sort((a, b) {
        final nodeA = nodesMap[a]!;
        final nodeB = nodesMap[b]!;
        return nodeA.order.compareTo(nodeB.order);
      });
    }

    return OutlinerInMemoryState(
      nodesMap: nodesMap,
      childrenPointerMap: childrenPointerMap,
    );
  }

  /// Get ordered list of all nodes (for serialization).
  List<OutlineNode> get allNodes => nodesMap.values.toList();

  /// Get children IDs for a given parent (null = root nodes).
  List<String> getChildrenIds(String? parentId) {
    return childrenPointerMap[parentId] ?? const [];
  }

  /// Check if a node has children.
  bool hasChildren(String nodeId) {
    final children = childrenPointerMap[nodeId];
    return children != null && children.isNotEmpty;
  }

  /// Get the previous sibling ID of a node, or null if first.
  String? getPreviousSiblingId(String nodeId) {
    final node = nodesMap[nodeId];
    if (node == null) return null;
    final siblings = getChildrenIds(node.parentId);
    final index = siblings.indexOf(nodeId);
    if (index <= 0) return null;
    return siblings[index - 1];
  }

  /// Get the next sibling ID of a node, or null if last.
  String? getNextSiblingId(String nodeId) {
    final node = nodesMap[nodeId];
    if (node == null) return null;
    final siblings = getChildrenIds(node.parentId);
    final index = siblings.indexOf(nodeId);
    if (index < 0 || index >= siblings.length - 1) return null;
    return siblings[index + 1];
  }

  OutlinerInMemoryState copyWith({
    Map<String, OutlineNode>? nodesMap,
    Map<String?, List<String>>? childrenPointerMap,
  }) {
    return OutlinerInMemoryState(
      nodesMap: nodesMap ?? this.nodesMap,
      childrenPointerMap: childrenPointerMap ?? this.childrenPointerMap,
    );
  }
}
