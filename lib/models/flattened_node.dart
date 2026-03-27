import 'outline_node.dart';

/// View model for a single row in the ListView.
/// Contains the node data plus computed display properties.
class FlattenedNode {
  final OutlineNode node;
  final int depth;
  final bool hasChildren;
  final bool isFolded;

  const FlattenedNode({
    required this.node,
    required this.depth,
    required this.hasChildren,
    required this.isFolded,
  });
}
