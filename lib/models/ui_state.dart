import 'dart:convert';

/// UI-specific state model, persisted separately from content
/// to avoid Git noise when just folding/unfolding nodes.
class OutlinerUIState {
  final Set<String> foldedNodes;
  final String? lastActiveNodeId;
  final double scrollPosition;
  final bool useLogicalOutdent;
  final Set<String> selectedNodeIds;
  final String? selectionAnchorId;

  const OutlinerUIState({
    this.foldedNodes = const {},
    this.lastActiveNodeId,
    this.scrollPosition = 0.0,
    this.useLogicalOutdent = true,
    this.selectedNodeIds = const {},
    this.selectionAnchorId,
  });

  OutlinerUIState copyWith({
    Set<String>? foldedNodes,
    String? Function()? lastActiveNodeId,
    double? scrollPosition,
    bool? useLogicalOutdent,
    Set<String>? selectedNodeIds,
    String? Function()? selectionAnchorId,
  }) {
    return OutlinerUIState(
      foldedNodes: foldedNodes ?? this.foldedNodes,
      lastActiveNodeId: lastActiveNodeId != null
          ? lastActiveNodeId()
          : this.lastActiveNodeId,
      scrollPosition: scrollPosition ?? this.scrollPosition,
      useLogicalOutdent: useLogicalOutdent ?? this.useLogicalOutdent,
      selectedNodeIds: selectedNodeIds ?? this.selectedNodeIds,
      selectionAnchorId: selectionAnchorId != null
          ? selectionAnchorId()
          : this.selectionAnchorId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'foldedNodes': foldedNodes.toList(),
      'lastActiveNodeId': lastActiveNodeId,
      'scrollPosition': scrollPosition,
      'useLogicalOutdent': useLogicalOutdent,
      // We explicitly don't serialize selection state because 
      // it's an ephemeral navigation state, not worth storing across sessions.
    };
  }

  factory OutlinerUIState.fromJson(Map<String, dynamic> json) {
    return OutlinerUIState(
      foldedNodes: (json['foldedNodes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          {},
      lastActiveNodeId: json['lastActiveNodeId'] as String?,
      scrollPosition: (json['scrollPosition'] as num?)?.toDouble() ?? 0.0,
      useLogicalOutdent: json['useLogicalOutdent'] as bool? ?? true,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory OutlinerUIState.fromJsonString(String source) {
    return OutlinerUIState.fromJson(
        jsonDecode(source) as Map<String, dynamic>);
  }
}
