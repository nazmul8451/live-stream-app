import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A premium, ultra-smooth "Swipe to Bid" slider widget for live auctions.
/// Features:
/// - Smooth horizontal drag physics with momentum / fling detection
/// - Spring-back animation on release
/// - Haptic feedback on successful swipe
/// - Dynamic visual states (Normal, Outbid, Bidding/Loading)
/// - Shimmering chevron guide
class SwipeToBidButton extends StatefulWidget {
  final double amount;
  final bool isOutbid;
  final bool isLoading;
  final VoidCallback onSwipeCompleted;
  final double height;
  final double width;

  const SwipeToBidButton({
    super.key,
    required this.amount,
    required this.onSwipeCompleted,
    this.isOutbid = false,
    this.isLoading = false,
    this.height = 48.0,
    this.width = 175.0,
  });

  @override
  State<SwipeToBidButton> createState() => _SwipeToBidButtonState();
}

class _SwipeToBidButtonState extends State<SwipeToBidButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _resetController;
  late Animation<double> _resetAnimation;

  double _dragOffset = 0.0;
  bool _completedTriggered = false;

  // Raw pointer tracking. The whole pill is the drag area and pointer events
  // are read directly (Listener), so a scrolling parent or a swipe that
  // starts beside the small knob can no longer steal the gesture.
  int? _pointer;
  double _startX = 0.0;
  double _lastX = 0.0;
  Duration _lastTime = Duration.zero;
  double _velocity = 0.0;

  // How far the knob must travel: bid on the spot at [_completeAt], or on
  // release past [_releaseAt].
  static const double _completeAt = 0.6;
  static const double _releaseAt = 0.35;

  // Knob diameter (slightly smaller than container height for padding)
  double get _knobSize => (widget.height - 8.h).clamp(36.0, 42.0);
  double get _padding => 4.w;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _resetController.addListener(() {
      setState(() {
        _dragOffset = _resetAnimation.value;
      });
    });
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent e) {
    if (widget.isLoading || _completedTriggered || _pointer != null) return;
    _resetController.stop();
    _pointer = e.pointer;
    _startX = e.localPosition.dx - _dragOffset;
    _lastX = e.localPosition.dx;
    _lastTime = e.timeStamp;
    _velocity = 0.0;
  }

  void _onPointerMove(PointerMoveEvent e, double maxDrag) {
    if (e.pointer != _pointer || widget.isLoading || _completedTriggered)
      return;
    final dt = (e.timeStamp - _lastTime).inMicroseconds;
    if (dt > 0) {
      _velocity = (e.localPosition.dx - _lastX) / dt * 1e6;
    }
    _lastX = e.localPosition.dx;
    _lastTime = e.timeStamp;
    final before = _dragOffset;
    setState(() {
      _dragOffset = (e.localPosition.dx - _startX).clamp(0.0, maxDrag);
    });
    // Light tick as the drag starts to count.
    if (before < maxDrag * 0.15 && _dragOffset >= maxDrag * 0.15) {
      HapticFeedback.selectionClick();
    }
    // Bid as soon as the knob is past 60%, without waiting for the finger
    // to lift, so a swipe feels instant.
    if (_dragOffset >= maxDrag * _completeAt) _triggerSuccess(maxDrag);
  }

  void _onPointerUp(double maxDrag) {
    _pointer = null;
    if (widget.isLoading || _completedTriggered) return;
    final progress = maxDrag > 0 ? _dragOffset / maxDrag : 0.0;
    // Released past a third, or any quick flick to the right.
    if (progress >= _releaseAt || (_velocity > 250 && progress >= 0.12)) {
      _triggerSuccess(maxDrag);
    } else if (_dragOffset > 0) {
      _animateReset(from: _dragOffset, to: 0.0);
    }
  }

  void _onPointerCancel() {
    _pointer = null;
    if (!_completedTriggered && _dragOffset > 0) {
      _animateReset(from: _dragOffset, to: 0.0);
    }
  }

  void _triggerSuccess(double maxDrag) {
    _completedTriggered = true;
    HapticFeedback.mediumImpact();

    // Snap to end
    _animateReset(from: _dragOffset, to: maxDrag, curve: Curves.easeOut);

    // Invoke action
    widget.onSwipeCompleted();

    // Reset back after brief pause
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _animateReset(from: maxDrag, to: 0.0, curve: Curves.easeOutCubic);
        setState(() {
          _completedTriggered = false;
        });
      }
    });
  }

  void _animateReset({
    required double from,
    required double to,
    Curve curve = Curves.easeOutCubic,
  }) {
    _resetAnimation = Tween<double>(
      begin: from,
      end: to,
    ).animate(CurvedAnimation(parent: _resetController, curve: curve));
    _resetController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width.w;
    final h = widget.height.h;
    final knobDiameter = _knobSize.r;
    final maxDrag = (w - knobDiameter - (_padding * 2)).clamp(0.0, 500.0);
    final progress = maxDrag > 0
        ? (_dragOffset / maxDrag).clamp(0.0, 1.0)
        : 0.0;

    final isOutbid = widget.isOutbid;
    final formattedAmount = "\$${widget.amount.toStringAsFixed(0)}";

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerMove: (e) => _onPointerMove(e, maxDrag),
      onPointerUp: (_) => _onPointerUp(maxDrag),
      onPointerCancel: (_) => _onPointerCancel(),
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(h / 2),
          color: isOutbid ? const Color(0xFFE5484D) : const Color(0xFF8B9BFF),
        ),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            // Dynamic slide fill behind knob
            if (progress > 0)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: (_dragOffset + knobDiameter + _padding).clamp(0.0, w),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(h / 2),
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
              ),

            // Track Label (Center text that gently fades as user slides)
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(left: knobDiameter + 8.w, right: 12.w),
                child: Opacity(
                  opacity: (1.0 - (progress * 1.5)).clamp(0.0, 1.0),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            isOutbid ? "Outbid · bid " : "Swipe to bid ",
                            style: TextStyle(
                              color: isOutbid
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : const Color(
                                      0xFF0F0B1E,
                                    ).withValues(alpha: 0.75),
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            formattedAmount,
                            style: TextStyle(
                              color: isOutbid
                                  ? Colors.white
                                  : const Color(0xFF0F0B1E),
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Draggable Knob / Slider Thumb
            Positioned(
              left: _padding + _dragOffset,
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: knobDiameter,
                  height: knobDiameter,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 6,
                        offset: const Offset(1, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: widget.isLoading
                        ? SizedBox(
                            width: 16.r,
                            height: 16.r,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isOutbid
                                    ? const Color(0xFFE5484D)
                                    : const Color(0xFF0F0B1E),
                              ),
                            ),
                          )
                        : Icon(
                            Icons.arrow_forward_rounded,
                            color: isOutbid
                                ? const Color(0xFFE5484D)
                                : const Color(0xFF0F0B1E),
                            size: 18.sp,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
