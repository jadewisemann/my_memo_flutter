import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/flattened_node.dart';
import '../../providers/providers.dart';
import '../controllers/markdown_highlight_controller.dart';
import '../theme.dart';
import '../shortcuts/shortcut_intents.dart';
import 'bullet_icon.dart';
import 'fold_icon.dart';

/// Individual row widget representing a single outliner node.
/// Renders: [indent] [fold icon] [bullet] [text field] [checkbox]
class OutlinerNodeWidget extends ConsumerStatefulWidget {
  final FlattenedNode flatNode;
  final int index;

  const OutlinerNodeWidget({
    super.key,
    required this.flatNode,
    required this.index,
  });

  @override
  ConsumerState<OutlinerNodeWidget> createState() => _OutlinerNodeWidgetState();
}

class _OutlinerNodeWidgetState extends ConsumerState<OutlinerNodeWidget> {
  late MarkdownHighlightController _controller;
  late FocusNode _focusNode;
  bool _isHovered = false;
  int _lastSelectAllTime = 0;

  @override
  void initState() {
    super.initState();
    _controller = MarkdownHighlightController()..text = widget.flatNode.node.text;
    _focusNode = FocusNode(onKeyEvent: _handleKeyEvent);

    _focusNode.addListener(_onFocusChange);

    // If instantiated natively into focus (e.g. lazy loading / scrolling)
    if (ref.read(focusedNodeIdProvider) == widget.flatNode.node.id) {
      _applyFocusJumpState();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  void _applyFocusJumpState() {
    final jumpReq = ref.read(focusJumpProvider);
    if (jumpReq != null) {
      ref.read(focusJumpProvider.notifier).set(null); // consume
      
      final String newText = _controller.text;
      int newOffset;
      
      if (jumpReq.isDown) {
        int firstNewlineIndex = newText.indexOf('\n');
        int firstLineLength = firstNewlineIndex == -1 ? newText.length : firstNewlineIndex;
        newOffset = jumpReq.column < firstLineLength ? jumpReq.column : firstLineLength;
      } else {
        int lastNewlineIndex = newText.lastIndexOf('\n');
        int lastLineStart = lastNewlineIndex == -1 ? 0 : lastNewlineIndex + 1;
        int lastLineLength = newText.length - lastLineStart;
        int col = jumpReq.column < lastLineLength ? jumpReq.column : lastLineLength;
        newOffset = lastLineStart + col;
      }

      newOffset = newOffset.clamp(0, newText.length);
      _controller.selection = TextSelection.collapsed(offset: newOffset);
    }
  }

  @override
  void didUpdateWidget(covariant OutlinerNodeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flatNode.node.text != widget.flatNode.node.text &&
        !_focusNode.hasFocus) {
      _controller.text = widget.flatNode.node.text;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    _controller.setFocus(_focusNode.hasFocus);
    if (_focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(focusedNodeIdProvider.notifier).set(widget.flatNode.node.id);
        ref.read(uiStateProvider.notifier).setActiveNode(widget.flatNode.node.id);
        // Clear selection mode if user clicks into text field
        ref.read(uiStateProvider.notifier).clearSelection();
      });
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final isMac = defaultTargetPlatform == TargetPlatform.macOS;
      final isModifierPressed = isMac
          ? HardwareKeyboard.instance.isMetaPressed
          : HardwareKeyboard.instance.isControlPressed;

      if (isModifierPressed && event.logicalKey == LogicalKeyboardKey.keyA) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastSelectAllTime < 500) {
          // Double Ctrl+A detected!
          FocusManager.instance.primaryFocus?.unfocus();
          ref.read(uiStateProvider.notifier).toggleSelectionMode(widget.flatNode.node.id);
          _lastSelectAllTime = 0; // Reset
          return KeyEventResult.handled;
        } else {
          _lastSelectAllTime = now;
        }
      }

      // Handle Multi-line Arrow Navigation (Up/Down) without modifiers
      if (!HardwareKeyboard.instance.isShiftPressed &&
          !HardwareKeyboard.instance.isAltPressed &&
          !HardwareKeyboard.instance.isControlPressed &&
          !HardwareKeyboard.instance.isMetaPressed) {
        
        final offset = _controller.selection.baseOffset;
        final text = _controller.text;

        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          if (offset >= 0 && text.substring(0, offset).contains('\n')) {
            // Internal movement allowed -> Let TextField bubble/handle naturally
            return KeyEventResult.ignored;
          } else {
            // Calculate column index before jumping
            int activeOffset = offset < 0 ? 0 : offset;
            int lastNewlineIndex = text.lastIndexOf('\n', activeOffset - 1);
            int targetColumn = activeOffset - (lastNewlineIndex == -1 ? 0 : lastNewlineIndex + 1);
            ref.read(focusJumpProvider.notifier).set(FocusJumpRequest(column: targetColumn, isDown: false));

            // Jump to previous node
            Actions.invoke(context, const MoveFocusUpIntent());
            return KeyEventResult.handled;
          }
        }
        
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          if (offset >= 0 && offset <= text.length && text.substring(offset).contains('\n')) {
            // Internal movement allowed -> Let TextField bubble/handle naturally
            return KeyEventResult.ignored;
          } else {
            // Calculate column index before jumping
            int activeOffset = offset < 0 ? 0 : offset;
            int lastNewlineIndex = text.lastIndexOf('\n', activeOffset - 1);
            int targetColumn = activeOffset - (lastNewlineIndex == -1 ? 0 : lastNewlineIndex + 1);
            ref.read(focusJumpProvider.notifier).set(FocusJumpRequest(column: targetColumn, isDown: true));

            // Jump to next node
            Actions.invoke(context, const MoveFocusDownIntent());
            return KeyEventResult.handled;
          }
        }
      }

      // Intercept Shift + Up/Down to bypass TextField text selection and trigger Block Selection
      if (HardwareKeyboard.instance.isShiftPressed &&
          !HardwareKeyboard.instance.isAltPressed &&
          !HardwareKeyboard.instance.isControlPressed &&
          !HardwareKeyboard.instance.isMetaPressed) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          Actions.invoke(context, const ExpandSelectionUpIntent());
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          Actions.invoke(context, const ExpandSelectionDownIntent());
          return KeyEventResult.handled;
        }
      }

      // Intercept Alt + Up/Down to bypass TextField handling and trigger Node Move
      if (HardwareKeyboard.instance.isAltPressed &&
          !HardwareKeyboard.instance.isShiftPressed &&
          !HardwareKeyboard.instance.isControlPressed &&
          !HardwareKeyboard.instance.isMetaPressed) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          Actions.invoke(context, const MoveSubtreeUpIntent());
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          Actions.invoke(context, const MoveSubtreeDownIntent());
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  void _onTextChanged(String value) {
    ref.read(outlinerProvider.notifier).updateText(
          widget.flatNode.node.id,
          value,
        );
  }

  void _onToggleFold() {
    ref.read(uiStateProvider.notifier).toggleFold(widget.flatNode.node.id);
  }

  void _onToggleComplete() {
    ref.read(outlinerProvider.notifier).toggleComplete(widget.flatNode.node.id);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(focusedNodeIdProvider, (previous, next) {
      if (next == widget.flatNode.node.id && !_focusNode.hasFocus) {
        _applyFocusJumpState();
        _focusNode.requestFocus();
      }
    });

    final node = widget.flatNode.node;
    final depth = widget.flatNode.depth;
    final hasChildren = widget.flatNode.hasChildren;
    final isFolded = widget.flatNode.isFolded;
    final isFocused = ref.watch(focusedNodeIdProvider) == node.id;
    
    final uiState = ref.watch(uiStateProvider);
    final isSelected = uiState.selectedNodeIds.contains(node.id);

    const double indentSize = 24.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentPrimary.withValues(alpha: 0.15)
              : isFocused
                  ? AppTheme.bgNodeFocused
                  : _isHovered
                      ? AppTheme.bgHover.withValues(alpha: 0.5)
                      : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        padding: EdgeInsets.only(
          left: depth * indentSize + 8,
          right: 8,
        ),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fold icon
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: FoldIcon(
                  isFolded: isFolded,
                  visible: hasChildren,
                  onTap: _onToggleFold,
                ),
              ),
              const SizedBox(width: 2),

              // Bullet
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: BulletIcon(
                  hasChildren: hasChildren,
                  isCompleted: node.isCompleted,
                ),
              ),
              const SizedBox(width: 6),

              // Text field
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  onChanged: _onTextChanged,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: node.isCompleted
                        ? AppTheme.textMuted
                        : AppTheme.textPrimary,
                    decoration:
                        node.isCompleted ? TextDecoration.lineThrough : null,
                    decorationColor: AppTheme.textMuted,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  cursorColor: AppTheme.accentPrimary,
                  cursorWidth: 1.5,
                ),
              ),

              // Checkbox (visible on hover or when completed)
              if (_isHovered || node.isCompleted)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 8),
                  child: GestureDetector(
                    onTap: _onToggleComplete,
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: Checkbox(
                        value: node.isCompleted,
                        onChanged: (_) => _onToggleComplete(),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
