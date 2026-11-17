import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class AppLoader extends StatelessWidget {
  const AppLoader({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) => Center(
        child: LoadingAnimationWidget.fourRotatingDots(
          color: Theme.of(context).colorScheme.primary,
          size: size,
        ),
      );
}
