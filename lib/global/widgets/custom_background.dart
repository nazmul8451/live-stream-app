import 'dart:ui';
import 'package:flutter/material.dart';

class CustomBackground extends StatelessWidget {
  final Widget? child;
  final Widget? bottomNavigationBar;
  final bool safeAreaTop;
  final bool safeAreaBottom;

  const CustomBackground({
    super.key,
    this.child,
    this.bottomNavigationBar,
    this.safeAreaTop = true,
    this.safeAreaBottom = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02010A),
      extendBody: bottomNavigationBar != null,
      bottomNavigationBar: bottomNavigationBar,
      body: Stack(
        children: [
          // Base Dark Background
          Container(
            width: double.infinity,
            height: double.infinity,
            color: const Color(0xFF02010A),
          ),

          // Right Side Pinkish/Purple Blob
          Positioned(
            top: MediaQuery.of(context).size.height * 0.2,
            right: -150,
            child: Container(
              width: 400,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4A1E4D).withOpacity(0.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A1E4D).withOpacity(0.5),
                    blurRadius: 150,
                    spreadRadius: 100,
                  ),
                ],
              ),
            ),
          ),

          // Bottom Left Deep Blue Blob
          Positioned(
            bottom: -150,
            left: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0A1435).withOpacity(0.6),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A1435).withOpacity(0.6),
                    blurRadius: 180,
                    spreadRadius: 120,
                  ),
                ],
              ),
            ),
          ),

          // Center Purple Glow
          Positioned(
            top: MediaQuery.of(context).size.height * 0.4,
            left: MediaQuery.of(context).size.width * 0.2,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E0B36).withOpacity(0.3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E0B36).withOpacity(0.3),
                    blurRadius: 200,
                    spreadRadius: 100,
                  ),
                ],
              ),
            ),
          ),

          // Glassmorphism Blur Layer - Blending everything
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 90.0, sigmaY: 90.0),
            child: Container(
              color: Colors.transparent,
            ),
          ),

          // Extra overlay to darken if needed
          Container(
            color: Colors.black.withOpacity(0.1),
          ),

          // Content
          if (child != null)
            SafeArea(
              top: safeAreaTop,
              bottom: safeAreaBottom,
              child: child!,
            ),
        ],
      ),
    );
  }
}
