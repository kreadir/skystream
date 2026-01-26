import 'package:flutter/material.dart';

class TvCardsWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scaleFactor;
  final bool autoFocus;
  final BorderRadius? borderRadius;
  final FocusNode? focusNode;

  const TvCardsWrapper({
    super.key,
    required this.child,
    required this.onTap,
    this.scaleFactor = 1.05,
    this.autoFocus = false,
    this.borderRadius,
    this.focusNode,
  });

  @override
  State<TvCardsWrapper> createState() => _TvCardsWrapperState();
}

class _TvCardsWrapperState extends State<TvCardsWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isFocused = false;
  late FocusNode _node;

  @override
  void initState() {
    super.initState();
    _node = widget.focusNode ?? FocusNode();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _node.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    if (widget.focusNode == null) _node.dispose();
    super.dispose();
  }

  bool _isHovered = false;

  void _updateAnimation() {
    if (_isFocused || _isHovered) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _onFocusChange(bool hasFocus) {
    setState(() {
      _isFocused = hasFocus;
    });
    _updateAnimation();
  }

  void _onHover(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });
    _updateAnimation();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      onFocusChange: _onFocusChange,
      onKey: (node, event) {
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onEnter: (_) => _onHover(true),
        onExit: (_) => _onHover(false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
                border: _isFocused
                    ? Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      )
                    : null,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
