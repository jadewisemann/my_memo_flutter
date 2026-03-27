import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/outline_node.dart';
import '../models/ui_state.dart';

// Conditional imports for dart:io
import 'file_service_stub.dart'
    if (dart.library.io) 'file_service_native.dart' as impl;

/// Handles all persistence for the outliner.
/// On native platforms: uses file system (JSONL + JSON).
/// On web: uses in-memory storage (no persistence across sessions).
class FileService {
  List<OutlineNode>? _memoryNodes;
  OutlinerUIState? _memoryUIState;

  /// Load all nodes from storage.
  Future<List<OutlineNode>> loadNodes() async {
    if (kIsWeb) {
      return _memoryNodes ?? [];
    }
    return impl.loadNodesFromDisk();
  }

  /// Save all nodes to storage.
  Future<void> saveAllNodes(List<OutlineNode> nodes) async {
    if (kIsWeb) {
      _memoryNodes = List.from(nodes);
      return;
    }
    return impl.saveAllNodesToDisk(nodes);
  }

  /// Load UI state from storage.
  Future<OutlinerUIState> loadUIState() async {
    if (kIsWeb) {
      return _memoryUIState ?? const OutlinerUIState();
    }
    return impl.loadUIStateFromDisk();
  }

  /// Save UI state to storage.
  Future<void> saveUIState(OutlinerUIState state) async {
    if (kIsWeb) {
      _memoryUIState = state;
      return;
    }
    return impl.saveUIStateToDisk(state);
  }
}
