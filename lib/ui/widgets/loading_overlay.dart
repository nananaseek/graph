import 'package:flutter/material.dart';

class LoadingOverlay extends StatelessWidget {
  final ValueNotifier<bool> isLoadingNotifier;
  final Widget child;

  const LoadingOverlay({
    super.key,
    required this.isLoadingNotifier,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        ValueListenableBuilder<bool>(
          valueListenable: isLoadingNotifier,
          builder: (context, isLoading, _) {
            if (!isLoading) return const SizedBox.shrink();

            return Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ],
    );
  }
}
