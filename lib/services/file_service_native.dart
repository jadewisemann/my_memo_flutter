import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/outline_node.dart';
import '../models/ui_state.dart';

const String _contentFileName = 'document.jsonl';
const String _uiStateFileName = 'document.ui.json';

String? _cachedDocPath;

Future<String> _getDocPath() async {
  if (_cachedDocPath != null) return _cachedDocPath!;
  final dir = await getApplicationDocumentsDirectory();
  final memoDir = Directory('${dir.path}/MyMemo');
  if (!await memoDir.exists()) {
    await memoDir.create(recursive: true);
  }
  _cachedDocPath = memoDir.path;
  return _cachedDocPath!;
}

Future<List<OutlineNode>> loadNodesFromDisk() async {
  final path = await _getDocPath();
  final file = File('$path/$_contentFileName');

  if (!await file.exists()) {
    return [];
  }

  final content = await file.readAsString();
  if (content.trim().isEmpty) return [];

  final lines = const LineSplitter().convert(content);
  final nodes = <OutlineNode>[];

  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    try {
      nodes.add(OutlineNode.fromJsonLine(line));
    } catch (e) {
      // Skip malformed lines
      // ignore: avoid_print
      print('Warning: Skipping malformed JSONL line: $e');
    }
  }

  return nodes;
}

Future<void> saveAllNodesToDisk(List<OutlineNode> nodes) async {
  final path = await _getDocPath();
  final file = File('$path/$_contentFileName');

  final sorted = List<OutlineNode>.from(nodes)
    ..sort((a, b) {
      final parentCmp = (a.parentId ?? '').compareTo(b.parentId ?? '');
      if (parentCmp != 0) return parentCmp;
      return a.order.compareTo(b.order);
    });

  final buffer = StringBuffer();
  for (final node in sorted) {
    buffer.writeln(node.toJsonLine());
  }

  await file.writeAsString(buffer.toString());
}

Future<OutlinerUIState> loadUIStateFromDisk() async {
  final path = await _getDocPath();
  final file = File('$path/$_uiStateFileName');

  if (!await file.exists()) {
    return const OutlinerUIState();
  }

  try {
    final content = await file.readAsString();
    return OutlinerUIState.fromJsonString(content);
  } catch (e) {
    return const OutlinerUIState();
  }
}

Future<void> saveUIStateToDisk(OutlinerUIState state) async {
  final path = await _getDocPath();
  final file = File('$path/$_uiStateFileName');
  final encoder = const JsonEncoder.withIndent('  ');
  await file.writeAsString(encoder.convert(state.toJson()));
}
