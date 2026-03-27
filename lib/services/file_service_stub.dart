/// Stub implementations for web platform.
/// On web, FileService uses in-memory storage, so these are never called.
import '../models/outline_node.dart';
import '../models/ui_state.dart';

Future<List<OutlineNode>> loadNodesFromDisk() async => [];
Future<void> saveAllNodesToDisk(List<OutlineNode> nodes) async {}
Future<OutlinerUIState> loadUIStateFromDisk() async => const OutlinerUIState();
Future<void> saveUIStateToDisk(OutlinerUIState state) async {}
