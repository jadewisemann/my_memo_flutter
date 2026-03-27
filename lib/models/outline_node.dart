import 'dart:convert';

/// Core data model representing a single node/line in the outliner.
/// Maps 1:1 to a line in document.jsonl.
class OutlineNode {
  final String id;
  final String text;
  final String? parentId;
  final String order;
  final bool isCompleted;

  const OutlineNode({
    required this.id,
    this.text = '',
    this.parentId,
    required this.order,
    this.isCompleted = false,
  });

  OutlineNode copyWith({
    String? id,
    String? text,
    String? Function()? parentId,
    String? order,
    bool? isCompleted,
  }) {
    return OutlineNode(
      id: id ?? this.id,
      text: text ?? this.text,
      parentId: parentId != null ? parentId() : this.parentId,
      order: order ?? this.order,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'parentId': parentId,
      'order': order,
      'isCompleted': isCompleted,
    };
  }

  factory OutlineNode.fromJson(Map<String, dynamic> json) {
    return OutlineNode(
      id: json['id'] as String,
      text: json['text'] as String? ?? '',
      parentId: json['parentId'] as String?,
      order: json['order'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }

  String toJsonLine() => jsonEncode(toJson());

  factory OutlineNode.fromJsonLine(String line) {
    return OutlineNode.fromJson(jsonDecode(line) as Map<String, dynamic>);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OutlineNode &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          text == other.text &&
          parentId == other.parentId &&
          order == other.order &&
          isCompleted == other.isCompleted;

  @override
  int get hashCode => Object.hash(id, text, parentId, order, isCompleted);

  @override
  String toString() =>
      'OutlineNode(id: $id, text: "$text", parentId: $parentId, order: $order, isCompleted: $isCompleted)';
}
