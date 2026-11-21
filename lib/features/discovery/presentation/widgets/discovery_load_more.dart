import 'package:flutter/widgets.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';

/// Asks for the next catalog page when a scroll ends near the bottom.
final class DiscoveryLoadMore extends StatelessWidget {
  const DiscoveryLoadMore({
    required this.onLoadMore,
    required this.child,
    super.key,
  });

  final Future<void> Function()? onLoadMore;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollEndNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter <= CandySpacing.section) {
          onLoadMore?.call();
        }
        return false;
      },
      child: child,
    );
  }
}
