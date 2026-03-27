import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import 'shortcut_intents.dart';

/// Create the action map for outliner shortcuts.
/// Each action calls the appropriate notifier method and handles complex
/// interactions like splitting a node based on cursor position.
Map<Type, Action<Intent>> buildOutlinerActions({
  required WidgetRef ref,
  required List<String> visibleNodeIds,
  required void Function(String nodeId) requestFocus,
  required VoidCallback defocusText,
  required int Function(String nodeId) getCursorPosition,
  required String Function(String nodeId) getText,
}) {
  void handleSelectionExpansion(bool isUp) {
    final focusedId = ref.read(focusedNodeIdProvider);
    if (focusedId == null) return;

    final uiState = ref.read(uiStateProvider);
    final selectionAnchorId = uiState.selectionAnchorId;
    final currentIdx = visibleNodeIds.indexOf(focusedId);

    if (selectionAnchorId == null) {
      // Start selection mode instantly from currently editing node
      // CRITICAL FIX: To prevent FocusManager infinite loops/crashes when intercepting
      // KeyEvents, we must NEVER unfocus synchronously inside an Action invoked by a Focus Listener.
      Future.delayed(Duration.zero, () {
        defocusText();
      });
      ref.read(uiStateProvider.notifier).toggleSelectionMode(focusedId);

      // Expand immediately
      final nextIdx = isUp ? currentIdx - 1 : currentIdx + 1;
      if (nextIdx >= 0 && nextIdx < visibleNodeIds.length) {
        final nextHeadId = visibleNodeIds[nextIdx];
        ref.read(focusedNodeIdProvider.notifier).set(nextHeadId);

        final newSelection = {focusedId, nextHeadId};
        ref.read(uiStateProvider.notifier).expandSelection(newSelection);
      }
      return;
    }

    // Expand structurally
    final anchorIdx = visibleNodeIds.indexOf(selectionAnchorId);
    if (anchorIdx == -1) return;

    final nextHeadIdx = isUp ? currentIdx - 1 : currentIdx + 1;
    if (nextHeadIdx >= 0 && nextHeadIdx < visibleNodeIds.length) {
      final nextHeadId = visibleNodeIds[nextHeadIdx];
      ref.read(focusedNodeIdProvider.notifier).set(nextHeadId);

      final startIdx = anchorIdx < nextHeadIdx ? anchorIdx : nextHeadIdx;
      final endIdx = anchorIdx > nextHeadIdx ? anchorIdx : nextHeadIdx;

      final newSelection = visibleNodeIds.sublist(startIdx, endIdx + 1).toSet();
      ref.read(uiStateProvider.notifier).expandSelection(newSelection);
    }
  }

  // Helper to extract top-level roots from the current multi-selection.
  // This prevents shearing and structural errors when processing commands on parent-child chains.
  List<String> getSelectionRoots() {
    final selectedIds = ref.read(uiStateProvider).selectedNodeIds;
    final outlinerState = ref.read(outlinerProvider);
    final roots = <String>[];
    
    for (final id in selectedIds) {
      bool hasSelectedAncestor = false;
      var node = outlinerState.nodesMap[id];
      while (node?.parentId != null) {
        if (selectedIds.contains(node!.parentId)) {
          hasSelectedAncestor = true;
          break;
        }
        node = outlinerState.nodesMap[node.parentId!];
      }
      if (!hasSelectedAncestor) {
        roots.add(id);
      }
    }
    return roots..sort((a, b) => visibleNodeIds.indexOf(a).compareTo(visibleNodeIds.indexOf(b)));
  }

  return {
    SplitOrCreateNodeIntent: CallbackAction<SplitOrCreateNodeIntent>(
      onInvoke: (intent) {
        final focusedId = ref.read(focusedNodeIdProvider);
        if (focusedId == null) return null;

        final node = ref.read(outlinerProvider).nodesMap[focusedId];
        if (node == null) return null;

        final cursorIndex = getCursorPosition(focusedId);
        final currentText = getText(focusedId);

        if (cursorIndex >= 0 && cursorIndex < currentText.length) {
          // Splitting node in the middle of text
          final leftText = currentText.substring(0, cursorIndex);
          final rightText = currentText.substring(cursorIndex);

          // CRITICAL BUG FIX: Execute focus changes and state mutations asynchronously
          // to prevent Flutter FocusManager concurrent modification crashes during key events.
          Future.delayed(Duration.zero, () {
            defocusText();
            ref.read(outlinerProvider.notifier).updateText(focusedId, leftText);

            final hasChildren = ref.read(outlinerProvider).hasChildren(focusedId);
            final isFolded = ref.read(uiStateProvider.notifier).isFolded(focusedId);
            final bool prependCurrent = hasChildren && !isFolded;

            final newId = ref.read(outlinerProvider.notifier).addNode(
                  parentId: prependCurrent ? focusedId : node.parentId,
                  afterNodeId: prependCurrent ? null : focusedId,
                  prependAsFirstChild: prependCurrent,
                  text: rightText,
                );

            WidgetsBinding.instance.addPostFrameCallback((_) {
              requestFocus(newId);
            });
          });
        } else {
          // Cursor is at end, create empty node based on context
          Future.delayed(Duration.zero, () {
            final hasChildren = ref.read(outlinerProvider).hasChildren(focusedId);
            final isFolded = ref.read(uiStateProvider.notifier).isFolded(focusedId);
            final bool prependCurrent = hasChildren && !isFolded;

            final newId = ref.read(outlinerProvider.notifier).addNode(
                  parentId: prependCurrent ? focusedId : node.parentId,
                  afterNodeId: prependCurrent ? null : focusedId,
                  prependAsFirstChild: prependCurrent,
                );

            WidgetsBinding.instance.addPostFrameCallback((_) {
              requestFocus(newId);
            });
          });
        }

        return null;
      },
    ),

    ForceCreateNodeBelowIntent: CallbackAction<ForceCreateNodeBelowIntent>(
      onInvoke: (intent) {
        final focusedId = ref.read(focusedNodeIdProvider);
        if (focusedId == null) return null;

        final node = ref.read(outlinerProvider).nodesMap[focusedId];
        if (node == null) return null;

        final newId = ref.read(outlinerProvider.notifier).addNode(
              parentId: node.parentId,
              afterNodeId: focusedId,
            );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          requestFocus(newId);
        });
        return null;
      },
    ),

    IndentNodeIntent: CallbackAction<IndentNodeIntent>(
      onInvoke: (intent) {
        final roots = getSelectionRoots();
        if (roots.isNotEmpty) {
          for (final id in roots) {
            ref.read(outlinerProvider.notifier).indentNode(id);
          }
          return null;
        }

        final focusedId = ref.read(focusedNodeIdProvider);
        if (focusedId == null) return null;
        ref.read(outlinerProvider.notifier).indentNode(focusedId);
        return null;
      },
    ),

    OutdentNodeIntent: CallbackAction<OutdentNodeIntent>(
      onInvoke: (intent) {
        final useLogicalOutdent = ref.read(uiStateProvider).useLogicalOutdent;
        final roots = getSelectionRoots();

        if (roots.isNotEmpty) {
          // CRITICAL FIX: Outdent MUST process from bottom to top (reversed) 
          // to prevent upper outdented nodes from stealing ordering slots.
          for (final id in roots.reversed) {
            if (useLogicalOutdent) {
              ref.read(outlinerProvider.notifier).performLogicalOutdent(id);
            } else {
              ref.read(outlinerProvider.notifier).performPositionalOutdent(id);
            }
          }
          return null;
        }

        final focusedId = ref.read(focusedNodeIdProvider);
        if (focusedId == null) return null;

        if (useLogicalOutdent) {
          ref.read(outlinerProvider.notifier).performLogicalOutdent(focusedId);
        } else {
          ref.read(outlinerProvider.notifier).performPositionalOutdent(focusedId);
        }
        return null;
      },
    ),

    MoveSubtreeUpIntent: CallbackAction<MoveSubtreeUpIntent>(
      onInvoke: (intent) {
        final roots = getSelectionRoots();
        if (roots.isNotEmpty) {
          ref.read(outlinerProvider.notifier).moveBlockUp(roots);
          return null;
        }
        
        final focusedId = ref.read(focusedNodeIdProvider);
        if (focusedId == null) return null;
        ref.read(outlinerProvider.notifier).moveNodeUp(focusedId);
        return null;
      },
    ),

    MoveSubtreeDownIntent: CallbackAction<MoveSubtreeDownIntent>(
      onInvoke: (intent) {
        final roots = getSelectionRoots();
        if (roots.isNotEmpty) {
          ref.read(outlinerProvider.notifier).moveBlockDown(roots);
          return null;
        }

        final focusedId = ref.read(focusedNodeIdProvider);
        if (focusedId == null) return null;
        ref.read(outlinerProvider.notifier).moveNodeDown(focusedId);
        return null;
      },
    ),

    ToggleFoldIntent: CallbackAction<ToggleFoldIntent>(
      onInvoke: (intent) {
        final focusedId = ref.read(focusedNodeIdProvider);
        if (focusedId == null) return null;
        ref.read(uiStateProvider.notifier).toggleFold(focusedId);
        return null;
      },
    ),

    MoveFocusUpIntent: CallbackAction<MoveFocusUpIntent>(
      onInvoke: (intent) {
        final focusedId = ref.read(focusedNodeIdProvider);
        if (focusedId == null) return null;
        final currentIdx = visibleNodeIds.indexOf(focusedId);
        if (currentIdx > 0) {
          requestFocus(visibleNodeIds[currentIdx - 1]);
        }
        return null;
      },
    ),

    MoveFocusDownIntent: CallbackAction<MoveFocusDownIntent>(
      onInvoke: (intent) {
        final focusedId = ref.read(focusedNodeIdProvider);
        if (focusedId == null) return null;
        final currentIdx = visibleNodeIds.indexOf(focusedId);
        if (currentIdx >= 0 && currentIdx < visibleNodeIds.length - 1) {
          requestFocus(visibleNodeIds[currentIdx + 1]);
        }
        return null;
      },
    ),

    ForceDeleteNodeIntent: CallbackAction<ForceDeleteNodeIntent>(
      onInvoke: (intent) {
        final roots = getSelectionRoots();
        if (roots.isNotEmpty) {
          for (final id in roots.reversed) {
            ref.read(outlinerProvider.notifier).deleteNode(id);
          }
          ref.read(uiStateProvider.notifier).clearSelection();
          return null;
        }
        
        final focusedId = ref.read(focusedNodeIdProvider);
        if (focusedId == null) return null;

        final focusTarget = ref.read(outlinerProvider.notifier).deleteNode(focusedId);
        if (focusTarget != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            requestFocus(focusTarget);
          });
        }
        return null;
      },
    ),

    ToggleNodeSelectionIntent: CallbackAction<ToggleNodeSelectionIntent>(
      onInvoke: (intent) {
        final focusedId = ref.read(focusedNodeIdProvider);
        if (focusedId == null) return null;

        // Enter selection mode and defocus text
        Future.delayed(Duration.zero, () {
          defocusText();
        });
        ref.read(uiStateProvider.notifier).toggleSelectionMode(focusedId);
        return null;
      },
    ),

    ExpandSelectionUpIntent: CallbackAction<ExpandSelectionUpIntent>(
      onInvoke: (intent) {
        handleSelectionExpansion(true);
        return null;
      },
    ),

    ExpandSelectionDownIntent: CallbackAction<ExpandSelectionDownIntent>(
      onInvoke: (intent) {
        handleSelectionExpansion(false);
        return null;
      },
    ),
  };
}
