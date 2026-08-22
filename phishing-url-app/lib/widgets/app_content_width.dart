import 'package:flutter/material.dart';

import '../theme/app_design.dart';

class AppContentWidth extends StatelessWidget {
  const AppContentWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppDesign.contentMaxWidth,
        ),
        child: child,
      ),
    );
  }
}
