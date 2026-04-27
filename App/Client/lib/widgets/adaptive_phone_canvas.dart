import 'package:flutter/material.dart';

class AdaptivePhoneCanvas extends StatelessWidget {
  final Widget child;
  final double designWidth;
  final double designHeight;

  const AdaptivePhoneCanvas({
    super.key,
    required this.child,
    this.designWidth = 390,
    this.designHeight = 844,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: designWidth,
              height: designHeight,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
