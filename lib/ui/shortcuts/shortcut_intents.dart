import 'package:flutter/material.dart';

/// Intent definitions for all outliner keyboard shortcuts.

// ─── Node Creation & Splitting ────────────────────────────────────────

/// Split the node if cursor in middle, or create sibling if at end (Enter)
class SplitOrCreateNodeIntent extends Intent {
  const SplitOrCreateNodeIntent();
}

/// Force create a new sibling below regardless of cursor (Ctrl/Cmd + Enter)
class ForceCreateNodeBelowIntent extends Intent {
  const ForceCreateNodeBelowIntent();
}

// ─── Node Hierarchy & Movement ────────────────────────────────────────

/// Indent the current node — make it a child of the previous sibling (Tab).
class IndentNodeIntent extends Intent {
  const IndentNodeIntent();
}

/// Outdent the current node — make it a sibling of the parent (Shift+Tab).
class OutdentNodeIntent extends Intent {
  const OutdentNodeIntent();
}

/// Move focus to the previous visible node (Up arrow).
class MoveFocusUpIntent extends Intent {
  const MoveFocusUpIntent();
}

/// Move focus to the next visible node (Down arrow).
class MoveFocusDownIntent extends Intent {
  const MoveFocusDownIntent();
}

/// Move the current node and its children up among siblings (Alt/Option + Up).
class MoveSubtreeUpIntent extends Intent {
  const MoveSubtreeUpIntent();
}

/// Move the current node and its children down among siblings (Alt/Option + Down).
class MoveSubtreeDownIntent extends Intent {
  const MoveSubtreeDownIntent();
}

/// Toggle fold state of the current node (Ctrl/Cmd + .).
class ToggleFoldIntent extends Intent {
  const ToggleFoldIntent();
}

// ─── Node Merging & Deletion ─────────────────────────────────────────

/// Merge node with previous sibling if cursor is at 0 (Backspace).
class MergeWithPreviousIntent extends Intent {
  const MergeWithPreviousIntent();
}

/// Hard delete the current node and all its descendants (Ctrl/Cmd + Shift + K).
class ForceDeleteNodeIntent extends Intent {
  const ForceDeleteNodeIntent();
}

/// Toggle Node Selection Mode (Ctrl/Cmd + L).
class ToggleNodeSelectionIntent extends Intent {
  const ToggleNodeSelectionIntent();
}

/// Instant Node Selection via Shift + Up.
class ExpandSelectionUpIntent extends Intent {
  const ExpandSelectionUpIntent();
}

/// Instant Node Selection via Shift + Down.
class ExpandSelectionDownIntent extends Intent {
  const ExpandSelectionDownIntent();
}
