import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/outline_node.dart';
import '../state/outliner_state.dart';
import '../services/file_service.dart';
import '../utils/fractional_index_helper.dart';
import 'providers.dart';

const _uuid = Uuid();

/// Riverpod Notifier managing the tree CRUD operations.
/// All mutations are O(1) for data manipulation (map updates).
class OutlinerNotifier extends Notifier<OutlinerInMemoryState> {
  Timer? _saveTimer;

  @override
  OutlinerInMemoryState build() {
    return const OutlinerInMemoryState();
  }

  FileService get _fileService => ref.read(fileServiceProvider);

  /// Load nodes from disk and populate in-memory state.
  Future<void> loadFromDisk() async {
    final nodes = await _fileService.loadNodes();
    if (nodes.isEmpty) {
      // Create sample document on first launch
      _createSampleDocument();
    } else {
      state = OutlinerInMemoryState.fromNodes(nodes);
    }
  }

  void _createSampleDocument() {
    final nodes = <OutlineNode>[];
    final keys = FractionalIndexHelper.generateNBetween(null, null, 3);

    final welcomeId = _uuid.v4();
    nodes.add(OutlineNode(
      id: welcomeId,
      text: 'Welcome to MyMemo',
      parentId: null,
      order: keys[0],
    ));

    final childKeys = FractionalIndexHelper.generateNBetween(null, null, 3);
    nodes.add(OutlineNode(
      id: _uuid.v4(),
      text: 'Press Enter to create a new line',
      parentId: welcomeId,
      order: childKeys[0],
    ));
    nodes.add(OutlineNode(
      id: _uuid.v4(),
      text: 'Press Tab to indent (make child)',
      parentId: welcomeId,
      order: childKeys[1],
    ));
    nodes.add(OutlineNode(
      id: _uuid.v4(),
      text: 'Press Shift+Tab to outdent',
      parentId: welcomeId,
      order: childKeys[2],
    ));

    final gettingStartedId = _uuid.v4();
    nodes.add(OutlineNode(
      id: gettingStartedId,
      text: 'Getting Started',
      parentId: null,
      order: keys[1],
    ));

    final gsChildKeys = FractionalIndexHelper.generateNBetween(null, null, 2);
    nodes.add(OutlineNode(
      id: _uuid.v4(),
      text: 'Use arrow keys to navigate between nodes',
      parentId: gettingStartedId,
      order: gsChildKeys[0],
    ));
    nodes.add(OutlineNode(
      id: _uuid.v4(),
      text: 'Use Ctrl+Arrow to move nodes up/down',
      parentId: gettingStartedId,
      order: gsChildKeys[1],
    ));

    nodes.add(OutlineNode(
      id: _uuid.v4(),
      text: 'Start outlining your thoughts!',
      parentId: null,
      order: keys[2],
    ));

    state = OutlinerInMemoryState.fromNodes(nodes);
    _scheduleSave();
  }

  /// Add a new node as sibling after [afterNodeId], or as first child of [parentId].
  /// Returns the new node's ID for focus management.
  String addNode({
    String? parentId,
    String? afterNodeId,
    bool prependAsFirstChild = false,
    String text = '',
  }) {
    final nodesMap = Map<String, OutlineNode>.from(state.nodesMap);
    final childrenMap = _cloneChildrenMap();

    // Calculate the new fractional index
    String newOrder;
    final siblings = state.getChildrenIds(parentId);

    if (prependAsFirstChild && siblings.isNotEmpty) {
      final firstChild = nodesMap[siblings.first]!;
      newOrder = FractionalIndexHelper.generateBefore(firstChild.order);
    } else if (afterNodeId != null && siblings.contains(afterNodeId)) {
      final afterIndex = siblings.indexOf(afterNodeId);
      final afterNode = nodesMap[afterNodeId]!;
      if (afterIndex < siblings.length - 1) {
        final nextNode = nodesMap[siblings[afterIndex + 1]]!;
        newOrder =
            FractionalIndexHelper.generateBetween(afterNode.order, nextNode.order);
      } else {
        newOrder = FractionalIndexHelper.generateAfter(afterNode.order);
      }
    } else if (siblings.isEmpty) {
      newOrder = FractionalIndexHelper.generateInitialIndex();
    } else {
      final lastNode = nodesMap[siblings.last]!;
      newOrder = FractionalIndexHelper.generateAfter(lastNode.order);
    }

    final newNode = OutlineNode(
      id: _uuid.v4(),
      text: text,
      parentId: parentId,
      order: newOrder,
    );

    nodesMap[newNode.id] = newNode;

    // Insert into children list at correct position
    final childList = childrenMap.putIfAbsent(parentId, () => []);
    if (prependAsFirstChild && childList.isNotEmpty) {
      childList.insert(0, newNode.id);
    } else if (afterNodeId != null) {
      final idx = childList.indexOf(afterNodeId);
      if (idx >= 0) {
        childList.insert(idx + 1, newNode.id);
      } else {
        childList.add(newNode.id);
      }
    } else {
      childList.add(newNode.id);
    }

    state = OutlinerInMemoryState(
      nodesMap: nodesMap,
      childrenPointerMap: childrenMap,
    );
    _scheduleSave();
    return newNode.id;
  }

  /// Update the text of a node. O(1) map update.
  void updateText(String nodeId, String newText) {
    final node = state.nodesMap[nodeId];
    if (node == null) return;

    final updatedNode = node.copyWith(text: newText);
    final nodesMap = Map<String, OutlineNode>.from(state.nodesMap);
    nodesMap[nodeId] = updatedNode;

    state = state.copyWith(nodesMap: nodesMap);
    _scheduleSave();
  }

  /// Toggle completion state of a node.
  void toggleComplete(String nodeId) {
    final node = state.nodesMap[nodeId];
    if (node == null) return;

    final updatedNode = node.copyWith(isCompleted: !node.isCompleted);
    final nodesMap = Map<String, OutlineNode>.from(state.nodesMap);
    nodesMap[nodeId] = updatedNode;

    state = state.copyWith(nodesMap: nodesMap);
    _scheduleSave();
  }

  /// Delete a node and all its descendants.
  /// Returns the ID of the node that should receive focus (previous sibling or parent).
  String? deleteNode(String nodeId) {
    final node = state.nodesMap[nodeId];
    if (node == null) return null;

    final nodesMap = Map<String, OutlineNode>.from(state.nodesMap);
    final childrenMap = _cloneChildrenMap();

    // Find focus target before deletion
    final siblings = childrenMap[node.parentId] ?? [];
    final idx = siblings.indexOf(nodeId);
    String? focusTarget;
    if (idx > 0) {
      focusTarget = siblings[idx - 1];
    } else {
      focusTarget = node.parentId;
    }

    // Recursively collect all descendant IDs
    void collectDescendants(String id, Set<String> collected) {
      collected.add(id);
      final children = childrenMap[id];
      if (children != null) {
        for (final childId in children) {
          collectDescendants(childId, collected);
        }
      }
    }

    final toRemove = <String>{};
    collectDescendants(nodeId, toRemove);

    // Remove from maps
    for (final id in toRemove) {
      nodesMap.remove(id);
      childrenMap.remove(id);
    }

    // Remove from parent's children list
    childrenMap[node.parentId]?.remove(nodeId);

    state = OutlinerInMemoryState(
      nodesMap: nodesMap,
      childrenPointerMap: childrenMap,
    );
    _scheduleSave();
    return focusTarget;
  }

  /// Indent node: make it a child of its previous sibling.
  bool indentNode(String nodeId) {
    final node = state.nodesMap[nodeId];
    if (node == null) return false;

    final prevSiblingId = state.getPreviousSiblingId(nodeId);
    if (prevSiblingId == null) return false; // Can't indent first sibling

    final nodesMap = Map<String, OutlineNode>.from(state.nodesMap);
    final childrenMap = _cloneChildrenMap();

    // Remove from current parent's children
    childrenMap[node.parentId]?.remove(nodeId);

    // Calculate new order: after last child of the new parent
    final newParentChildren = childrenMap[prevSiblingId] ?? [];
    String newOrder;
    if (newParentChildren.isEmpty) {
      newOrder = FractionalIndexHelper.generateInitialIndex();
    } else {
      final lastChild = nodesMap[newParentChildren.last]!;
      newOrder = FractionalIndexHelper.generateAfter(lastChild.order);
    }

    // Update node
    final updatedNode = node.copyWith(
      parentId: () => prevSiblingId,
      order: newOrder,
    );
    nodesMap[nodeId] = updatedNode;

    // Add to new parent's children
    childrenMap.putIfAbsent(prevSiblingId, () => []).add(nodeId);

    state = OutlinerInMemoryState(
      nodesMap: nodesMap,
      childrenPointerMap: childrenMap,
    );
    _scheduleSave();
    return true;
  }

  /// Logical Outdent: make node a sibling of its current parent.
  /// Node moves out, and its sub-tree (children) implicitly moves with it.
  bool performLogicalOutdent(String nodeId) {
    final node = state.nodesMap[nodeId];
    if (node == null || node.parentId == null) return false; // Root can't outdent

    final parent = state.nodesMap[node.parentId!];
    if (parent == null) return false;

    final nodesMap = Map<String, OutlineNode>.from(state.nodesMap);
    final childrenMap = _cloneChildrenMap();

    // Remove from current parent's children
    childrenMap[node.parentId]?.remove(nodeId);

    // Calculate new order: after the parent in grandparent's children
    final grandparentChildren = childrenMap[parent.parentId] ?? [];
    final parentIdx = grandparentChildren.indexOf(parent.id);
    String newOrder;
    if (parentIdx < grandparentChildren.length - 1) {
      final nextSibling = nodesMap[grandparentChildren[parentIdx + 1]]!;
      newOrder = FractionalIndexHelper.generateBetween(
          parent.order, nextSibling.order);
    } else {
      newOrder = FractionalIndexHelper.generateAfter(parent.order);
    }

    // Update node
    final updatedNode = node.copyWith(
      parentId: () => parent.parentId,
      order: newOrder,
    );
    nodesMap[nodeId] = updatedNode;

    // Insert into grandparent's children after the parent
    final gpChildren =
        childrenMap.putIfAbsent(parent.parentId, () => []);
    final gpParentIdx = gpChildren.indexOf(parent.id);
    gpChildren.insert(gpParentIdx + 1, nodeId);

    state = OutlinerInMemoryState(
      nodesMap: nodesMap,
      childrenPointerMap: childrenMap,
    );
    _scheduleSave();
    return true;
  }

  /// Positional Outdent (IDE style): Moves the node out, leaving its children behind in its place.
  bool performPositionalOutdent(String nodeId) {
    final node = state.nodesMap[nodeId];
    if (node == null || node.parentId == null) return false;

    final parent = state.nodesMap[node.parentId!];
    if (parent == null) return false;

    final nodesMap = Map<String, OutlineNode>.from(state.nodesMap);
    final childrenMap = _cloneChildrenMap();

    // 1. Determine N's original location inside P
    final parentChildren = childrenMap[parent.id]!;
    final nIndexInP = parentChildren.indexOf(nodeId);
    
    // Save the order of the next sibling to place the orphaned children safely
    final nextSibOrder = nIndexInP < parentChildren.length - 1
        ? nodesMap[parentChildren[nIndexInP + 1]]!.order
        : null;
    final nOldOrder = node.order;

    // 2. Remove N from P's children
    parentChildren.remove(nodeId);

    // 3. Reparent N to G, placing it immediately after P
    final grandparentChildren = childrenMap[parent.parentId] ?? [];
    final parentIdx = grandparentChildren.indexOf(parent.id);
    String newOrderForN;
    if (parentIdx < grandparentChildren.length - 1) {
      final nextSiblingOfP = nodesMap[grandparentChildren[parentIdx + 1]]!;
      newOrderForN = FractionalIndexHelper.generateBetween(parent.order, nextSiblingOfP.order);
    } else {
      newOrderForN = FractionalIndexHelper.generateAfter(parent.order);
    }

    nodesMap[nodeId] = node.copyWith(
      parentId: () => parent.parentId,
      order: newOrderForN,
    );

    final gpChildren = childrenMap.putIfAbsent(parent.parentId, () => []);
    final gpParentIdx = gpChildren.indexOf(parent.id);
    gpChildren.insert(gpParentIdx + 1, nodeId);

    // 4. Orphan N's children to P, slotting them exactly where N was
    final childrenOfN = childrenMap[nodeId] ?? [];
    if (childrenOfN.isNotEmpty) {
      String prevChildOrder = "";
      for (int i = 0; i < childrenOfN.length; i++) {
        final childId = childrenOfN[i];
        final child = nodesMap[childId]!;
        
        String newChildOrder;
        if (i == 0) {
          // The first child perfectly takes over N's old fractional index
          newChildOrder = nOldOrder; 
        } else {
          // Subsequent children fit between the previous child and N's next sibling
          newChildOrder = nextSibOrder != null
              ? FractionalIndexHelper.generateBetween(prevChildOrder, nextSibOrder)
              : FractionalIndexHelper.generateAfter(prevChildOrder);
        }
        
        prevChildOrder = newChildOrder;

        nodesMap[childId] = child.copyWith(
          parentId: () => parent.id,
          order: newChildOrder,
        );
        // Insert them sequentially into the space where N was
        parentChildren.insert(nIndexInP + i, childId);
      }
      
      // Clear N's children record as they are all orphaned
      childrenMap[nodeId] = [];
    }

    state = OutlinerInMemoryState(
      nodesMap: nodesMap,
      childrenPointerMap: childrenMap,
    );
    _scheduleSave();
    return true;
  }

  /// Move a node up among its siblings (swap order with the previous sibling).
  bool moveNodeUp(String nodeId) {
    final node = state.nodesMap[nodeId];
    if (node == null) return false;

    final siblings = List<String>.from(state.getChildrenIds(node.parentId));
    final idx = siblings.indexOf(nodeId);
    if (idx <= 0) return false;

    final nodesMap = Map<String, OutlineNode>.from(state.nodesMap);
    final childrenMap = _cloneChildrenMap();

    // Swap orders between current node and previous sibling
    final prevId = siblings[idx - 1];
    final prevNode = nodesMap[prevId]!;

    nodesMap[nodeId] = node.copyWith(order: prevNode.order);
    nodesMap[prevId] = prevNode.copyWith(order: node.order);

    // Swap positions in children list
    final childList = childrenMap[node.parentId]!;
    final i = childList.indexOf(nodeId);
    final j = childList.indexOf(prevId);
    final temp = childList[i];
    childList[i] = childList[j];
    childList[j] = temp;

    state = OutlinerInMemoryState(
      nodesMap: nodesMap,
      childrenPointerMap: childrenMap,
    );
    _scheduleSave();
    return true;
  }

  /// Move a node down among its siblings.
  bool moveNodeDown(String nodeId) {
    final node = state.nodesMap[nodeId];
    if (node == null) return false;

    final siblings = List<String>.from(state.getChildrenIds(node.parentId));
    final idx = siblings.indexOf(nodeId);
    if (idx < 0 || idx >= siblings.length - 1) return false;

    final nodesMap = Map<String, OutlineNode>.from(state.nodesMap);
    final childrenMap = _cloneChildrenMap();

    // Swap orders
    final nextId = siblings[idx + 1];
    final nextNode = nodesMap[nextId]!;

    nodesMap[nodeId] = node.copyWith(order: nextNode.order);
    nodesMap[nextId] = nextNode.copyWith(order: node.order);

    // Swap positions in children list
    final childList = childrenMap[node.parentId]!;
    final i = childList.indexOf(nodeId);
    final j = childList.indexOf(nextId);
    final temp = childList[i];
    childList[i] = childList[j];
    childList[j] = temp;

    state = OutlinerInMemoryState(
      nodesMap: nodesMap,
      childrenPointerMap: childrenMap,
    );
    _scheduleSave();
    return true;
  }

  /// Bulk block movement up
  bool moveBlockUp(List<String> blockIds) {
    if (blockIds.isEmpty) return false;
    final parentId = state.nodesMap[blockIds.first]?.parentId;
    
    // Validate identical parents
    for (final id in blockIds) {
      if (state.nodesMap[id]?.parentId != parentId) return false;
    }

    final siblings = List<String>.from(state.getChildrenIds(parentId));
    final firstIdx = siblings.indexOf(blockIds.first);
    if (firstIdx <= 0) return false;

    final nodesMap = Map<String, OutlineNode>.from(state.nodesMap);
    final childrenMap = _cloneChildrenMap();

    // The sibling we are swapping with
    final prevId = siblings[firstIdx - 1];
    
    // Mathematically, if we move a block up, the block takes the fractional range starting at prevId's order,
    // and prevId takes the order of the last item in the block.
    // To strictly preserve relative ordering without regenerating all keys, 
    // we just swap elements in `childrenMap` list, and regenerate keys for the block.
    // But regenerating keys is tricky. Actually, we can just do pairwise swaps down the line!
    // Since it's a contiguous block, moving [B,C] above [A] is identical to moving A down twice!
    
    String currentTargetId = prevId;
    for (int i = 0; i < blockIds.length; i++) {
        // We will move currentTargetId down strictly by swapping positions with blockIds[i]
        final bId = blockIds[i];
        
        // Swap orders
        final bNode = nodesMap[bId]!;
        final tgNode = nodesMap[currentTargetId]!;
        nodesMap[bId] = bNode.copyWith(order: tgNode.order);
        nodesMap[currentTargetId] = tgNode.copyWith(order: bNode.order);
        
        // Swap positions in child list
        final list = childrenMap[parentId]!;
        final idxB = list.indexOf(bId);
        final idxTg = list.indexOf(currentTargetId);
        final temp = list[idxB];
        list[idxB] = list[idxTg];
        list[idxTg] = temp;
    }

    state = OutlinerInMemoryState(
      nodesMap: nodesMap,
      childrenPointerMap: childrenMap,
    );
    _scheduleSave();
    return true;
  }

  /// Bulk block movement down
  bool moveBlockDown(List<String> blockIds) {
    if (blockIds.isEmpty) return false;
    final parentId = state.nodesMap[blockIds.first]?.parentId;
    
    for (final id in blockIds) {
      if (state.nodesMap[id]?.parentId != parentId) return false;
    }

    final siblings = List<String>.from(state.getChildrenIds(parentId));
    final lastIdx = siblings.indexOf(blockIds.last);
    if (lastIdx < 0 || lastIdx >= siblings.length - 1) return false;

    final nodesMap = Map<String, OutlineNode>.from(state.nodesMap);
    final childrenMap = _cloneChildrenMap();

    final nextId = siblings[lastIdx + 1];
    
    String currentTargetId = nextId;
    for (int i = blockIds.length - 1; i >= 0; i--) {
        final bId = blockIds[i];
        
        // Swap orders
        final bNode = nodesMap[bId]!;
        final tgNode = nodesMap[currentTargetId]!;
        nodesMap[bId] = bNode.copyWith(order: tgNode.order);
        nodesMap[currentTargetId] = tgNode.copyWith(order: bNode.order);
        
        // Swap positions
        final list = childrenMap[parentId]!;
        final idxB = list.indexOf(bId);
        final idxTg = list.indexOf(currentTargetId);
        final temp = list[idxB];
        list[idxB] = list[idxTg];
        list[idxTg] = temp;
    }

    state = OutlinerInMemoryState(
      nodesMap: nodesMap,
      childrenPointerMap: childrenMap,
    );
    _scheduleSave();
    return true;
  }

  /// Merges the current node text into the previous visible node,
  /// reparents its children, and deletes the current node.
  /// Returns the ID of the node that received the merged text (for focus).
  String? mergeNodeWithPrevious(String nodeId, List<OutlineNode> flattenedList) {
    final node = state.nodesMap[nodeId];
    if (node == null) return null;

    final idx = flattenedList.indexWhere((n) => n.id == nodeId);
    if (idx <= 0) return null; // Can't merge the very first node

    final prevNode = flattenedList[idx - 1]; // Previous visible node

    final nodesMap = Map<String, OutlineNode>.from(state.nodesMap);
    final childrenMap = _cloneChildrenMap();

    // 1. Update previous node's text by appending current node's text
    final updatedPrevNode = prevNode.copyWith(text: prevNode.text + node.text);
    nodesMap[prevNode.id] = updatedPrevNode;

    // 2. Reparent current node's children to previous node
    final childrenOfNode = childrenMap[nodeId] ?? [];
    if (childrenOfNode.isNotEmpty) {
      final prevNodeChildren = childrenMap.putIfAbsent(prevNode.id, () => []);

      // We must append them after existing children to avoid order clashes
      String lastOrder = prevNodeChildren.isEmpty
          ? FractionalIndexHelper.generateInitialIndex()
          : nodesMap[prevNodeChildren.last]!.order;

      for (final childId in childrenOfNode) {
        final child = nodesMap[childId]!;
        lastOrder = FractionalIndexHelper.generateAfter(lastOrder);
        nodesMap[childId] = child.copyWith(
          parentId: () => prevNode.id,
          order: lastOrder,
        );
        prevNodeChildren.add(childId);
      }
    }

    // 3. Remove current node
    childrenMap.remove(nodeId);
    childrenMap[node.parentId]?.remove(nodeId);
    nodesMap.remove(nodeId);

    state = OutlinerInMemoryState(
      nodesMap: nodesMap,
      childrenPointerMap: childrenMap,
    );
    _scheduleSave();

    return prevNode.id;
  }

  /// Deep clone the children pointer map.
  Map<String?, List<String>> _cloneChildrenMap() {
    return state.childrenPointerMap
        .map((key, value) => MapEntry(key, List<String>.from(value)));
  }

  /// Schedule a debounced save (500ms after last mutation).
  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      _fileService.saveAllNodes(state.allNodes);
    });
  }
}
