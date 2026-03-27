import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flattened_node.dart';
import '../providers/providers.dart';
import 'shortcuts/shortcut_actions.dart';
import 'shortcuts/shortcut_bindings.dart';

import 'theme.dart';
import 'widgets/outliner_node_widget.dart';

/// Main outliner page with virtualized ListView and keyboard shortcuts.
class OutlinerPage extends ConsumerStatefulWidget {
  const OutlinerPage({super.key});

  @override
  ConsumerState<OutlinerPage> createState() => _OutlinerPageState();
}

class _OutlinerPageState extends ConsumerState<OutlinerPage> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;

  /// Map of node ID → GlobalKey for focus management.
  final Map<String, GlobalKey<_NodeFocusWrapperState>> _nodeKeys = {};

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await ref.read(outlinerProvider.notifier).loadFromDisk();
    await ref.read(uiStateProvider.notifier).loadFromDisk();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _requestFocus(String nodeId) {
    final key = _nodeKeys[nodeId];
    if (key?.currentState != null) {
      key!.currentState!.requestFocus();
    }
    ref.read(focusedNodeIdProvider.notifier).set(nodeId);
  }

  int _getCursorPosition(String nodeId) {
    return _nodeKeys[nodeId]?.currentState?.getCursorPosition() ?? -1;
  }

  TextSelection? _getSelection(String nodeId) {
    return _nodeKeys[nodeId]?.currentState?.getSelection();
  }

  String _getText(String nodeId) {
    return _nodeKeys[nodeId]?.currentState?.getText() ?? '';
  }

  /// Handle raw key events for arrow-key focus navigation
  /// (which can't be handled via Shortcuts because TextField consumes them).
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final focusedId = ref.read(focusedNodeIdProvider);
    if (focusedId == null) return KeyEventResult.ignored;

    final flatList = ref.read(flattenedListProvider);
    final visibleIds = flatList.map((n) => n.node.id).toList();
    final currentIdx = visibleIds.indexOf(focusedId);

    final uiState = ref.read(uiStateProvider);
    final selectedNodeIds = uiState.selectedNodeIds;
    
    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
    final isArrowUp = event.logicalKey == LogicalKeyboardKey.arrowUp;
    final isArrowDown = event.logicalKey == LogicalKeyboardKey.arrowDown;
    final isPageFocus = FocusManager.instance.primaryFocus == _pageFocusNode;

    // Up arrow (without modifier) → move focus up
    if (isArrowUp &&
        !isShiftPressed &&
        !HardwareKeyboard.instance.isAltPressed &&
        !HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isMetaPressed) {
      if (selectedNodeIds.isNotEmpty) ref.read(uiStateProvider.notifier).clearSelection();
      
      // If editing a node, OutlinerNodeWidget handles node jumping. We only navigate via Page if fully defocused.
      if (isPageFocus && currentIdx > 0) {
        _requestFocus(visibleIds[currentIdx - 1]);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // Down arrow (without modifier) → move focus down
    if (isArrowDown &&
        !isShiftPressed &&
        !HardwareKeyboard.instance.isAltPressed &&
        !HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isMetaPressed) {
      if (selectedNodeIds.isNotEmpty) ref.read(uiStateProvider.notifier).clearSelection();
      
      if (isPageFocus && currentIdx >= 0 && currentIdx < visibleIds.length - 1) {
        _requestFocus(visibleIds[currentIdx + 1]);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // Backspace: merge if at 0 and NO text is selected. Else, let TextField handle it.
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      final node = ref.read(outlinerProvider).nodesMap[focusedId];
      if (node != null) {
        final selection = _getSelection(focusedId);
        
        if (selection == null) return KeyEventResult.ignored;

        // Condition 1: Text is highlighted. Let TextField delete natively!
        if (!selection.isCollapsed) return KeyEventResult.ignored;

        // Condition 2: Cursor is NOT at beginning. Let TextField delete character natively!
        if (selection.baseOffset > 0) return KeyEventResult.ignored;

        // Condition 3: Cursor is at exactly 0 and NO text is selected -> Merge Up
        final focusTarget = ref.read(outlinerProvider.notifier)
            .mergeNodeWithPrevious(focusedId, flatList.map((f) => f.node).toList());
            
        if (focusTarget != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _requestFocus(focusTarget);
          });
        }
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  final FocusNode _pageFocusNode = FocusNode();

  void _defocusText() {
    _pageFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.bgPrimary,
        body: Center(
          child: CircularProgressIndicator(
            color: AppTheme.accentPrimary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    final flatList = ref.watch(flattenedListProvider);
    final visibleIds = flatList.map((n) => n.node.id).toList();

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: Shortcuts(
        shortcuts: outlinerShortcuts,
        child: Actions(
          actions: buildOutlinerActions(
            ref: ref,
            visibleNodeIds: visibleIds,
            requestFocus: _requestFocus,
            defocusText: _defocusText,
            getCursorPosition: _getCursorPosition,
            getText: _getText,
          ),
          child: Focus(
            focusNode: _pageFocusNode,
            autofocus: true,
            onKeyEvent: _handleKeyEvent,
            child: Column(
              children: [
                // ─── Toolbar ───────────────────────────────────────────
                _buildToolbar(context),

                // ─── Divider ───────────────────────────────────────────
                Divider(height: 1, color: AppTheme.borderSubtle),

                // ─── Tree View ─────────────────────────────────────────
                Expanded(
                  child: flatList.isEmpty
                      ? _buildEmptyState()
                      : _buildTreeView(flatList),
                ),

                // ─── Status Bar ────────────────────────────────────────
                _buildStatusBar(flatList.length),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary,
      ),
      child: Row(
        children: [
          // App icon
          Icon(
            Icons.account_tree_rounded,
            color: AppTheme.accentPrimary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            'MyMemo',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // Keyboard shortcuts hint
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.bgTertiary,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Text(
              'Ctrl+. fold  ·  Tab indent  ·  Enter new line',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.note_add_rounded,
            size: 48,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            'Your outline is empty',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start typing to create your first node',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreeView(List<FlattenedNode> flatList) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: flatList.length,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      itemBuilder: (context, index) {
        final flatNode = flatList[index];

        // Manage GlobalKeys for focus targeting
        _nodeKeys.putIfAbsent(
          flatNode.node.id,
          () => GlobalKey<_NodeFocusWrapperState>(),
        );

        return _NodeFocusWrapper(
          key: _nodeKeys[flatNode.node.id],
          flatNode: flatNode,
          index: index,
        );
      },
    );
  }

  Widget _buildStatusBar(int nodeCount) {
    final totalNodes = ref.watch(outlinerProvider).nodesMap.length;

    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary,
        border: Border(
          top: BorderSide(color: AppTheme.borderSubtle),
        ),
      ),
      child: Row(
        children: [
          Text(
            '$totalNodes nodes',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$nodeCount visible',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
            ),
          ),
          const Spacer(),
          Text(
            'MyMemo v1.0',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Wrapper that provides a focus target for each node.
class _NodeFocusWrapper extends ConsumerStatefulWidget {
  final FlattenedNode flatNode;
  final int index;

  const _NodeFocusWrapper({
    super.key,
    required this.flatNode,
    required this.index,
  });

  @override
  ConsumerState<_NodeFocusWrapper> createState() => _NodeFocusWrapperState();
}

class _NodeFocusWrapperState extends ConsumerState<_NodeFocusWrapper> {
  void requestFocus() {
    // Find the OutlinerNodeWidget's TextField and focus it
    // We need to find the first TextField in our subtree
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderObject = context.findRenderObject();
      if (renderObject == null) return;

      // Walk the element tree to find the TextField's FocusNode
      void visitElement(Element element) {
        if (element.widget is TextField) {
          final textField = element.widget as TextField;
          textField.focusNode?.requestFocus();
          return;
        }
        element.visitChildren(visitElement);
      }

      (context as Element).visitChildren(visitElement);
    });
  }

  int getCursorPosition() {
    int pos = -1;
    void visitElement(Element element) {
      if (element.widget is TextField) {
        final textField = element.widget as TextField;
        pos = textField.controller?.selection.baseOffset ?? -1;
        return;
      }
      if (pos == -1) element.visitChildren(visitElement);
    }
    if (mounted) (context as Element).visitChildren(visitElement);
    return pos;
  }

  TextSelection? getSelection() {
    TextSelection? sel;
    void visitElement(Element element) {
      if (element.widget is TextField) {
        final textField = element.widget as TextField;
        sel = textField.controller?.selection;
        return;
      }
      if (sel == null) element.visitChildren(visitElement);
    }
    if (mounted) (context as Element).visitChildren(visitElement);
    return sel;
  }

  String getText() {
    String txt = '';
    void visitElement(Element element) {
      if (element.widget is TextField) {
        final textField = element.widget as TextField;
        txt = textField.controller?.text ?? '';
        return;
      }
      if (txt.isEmpty) element.visitChildren(visitElement);
    }
    if (mounted) (context as Element).visitChildren(visitElement);
    return txt;
  }

  @override
  Widget build(BuildContext context) {
    return OutlinerNodeWidget(
      flatNode: widget.flatNode,
      index: widget.index,
    );
  }
}
