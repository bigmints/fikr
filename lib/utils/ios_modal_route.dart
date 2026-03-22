import 'package:flutter/material.dart';

/// iOS-style fullscreen modal route.
///
/// The incoming page slides up from the bottom with rounded top corners,
/// while the previous page scales down and gets rounded corners,
/// creating the native iOS sheet-on-top-of-page effect.
class IosModalRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  IosModalRoute({required this.page})
    : super(
        opaque: false,
        barrierColor: Colors.black54,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );

          // Slide up from bottom
          final slideAnimation = Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curvedAnimation);

          // Scale the modal very slightly for a polished feel
          final scaleAnimation = Tween<double>(
            begin: 0.95,
            end: 1.0,
          ).animate(curvedAnimation);

          final screenHeight = MediaQuery.of(context).size.height;
          final topInset = MediaQuery.of(context).padding.top;
          // Leave a small gap at the top showing the status bar area
          final topOffset = topInset + 10;

          return Stack(
            children: [
              // Background dimming handled by barrierColor

              // Modal sheet
              SlideTransition(
                position: slideAnimation,
                child: ScaleTransition(
                  scale: scaleAnimation,
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: topOffset),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: SizedBox(
                        height: screenHeight - topOffset,
                        width: double.infinity,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
}
