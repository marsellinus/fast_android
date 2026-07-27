import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final Border? border;
  final Color? color;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.blur = 10,
    this.opacity = 0.05,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius,
    this.border,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(24);
    final innerColor = color ?? Colors.white;
    
    Widget content = ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: innerColor.withValues(alpha: opacity),
            borderRadius: br,
            border: border ??
                Border.all(
                  color: innerColor.withValues(alpha: opacity * 2),
                  width: 1.5,
                ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                spreadRadius: -2,
              )
            ],
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: br,
        child: InkWell(
          borderRadius: br,
          onTap: onTap,
          highlightColor: innerColor.withValues(alpha: 0.1),
          splashColor: innerColor.withValues(alpha: 0.1),
          child: content,
        ),
      );
    }
    
    return content;
  }
}
