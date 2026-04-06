import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/async_action_controller.dart';

class ResponsiveActionButton extends StatelessWidget {
  const ResponsiveActionButton({
    super.key,
    required this.actionKey,
    required this.asyncController,
    required this.onPressed,
    required this.child,
    this.debounceDuration = const Duration(milliseconds: 150),
    this.progressSize = 16,
    this.style,
    this.tooltip,
  });

  final String actionKey;
  final AsyncActionController asyncController;
  final Future<void> Function() onPressed;
  final Widget child;
  final Duration debounceDuration;
  final double progressSize;
  final ButtonStyle? style;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final running = asyncController.isRunning(actionKey);
      final button = ElevatedButton(
        onPressed: running
            ? null
            : () async {
                await asyncController.run<void>(actionKey, onPressed);
              },
        style: style,
        child: AnimatedSwitcher(
          duration: debounceDuration,
          child: running
              ? SizedBox(
                  key: const ValueKey('busy'),
                  width: progressSize,
                  height: progressSize,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : KeyedSubtree(
                  key: const ValueKey('idle'),
                  child: child,
                ),
        ),
      );
      if (tooltip == null) return button;
      return Tooltip(message: tooltip!, child: button);
    });
  }
}

class ResponsiveIconButton extends StatelessWidget {
  const ResponsiveIconButton({
    super.key,
    required this.actionKey,
    required this.asyncController,
    required this.onPressed,
    required this.icon,
    this.debounceDuration = const Duration(milliseconds: 150),
    this.progressSize = 14,
    this.tooltip,
    this.style,
  });

  final String actionKey;
  final AsyncActionController asyncController;
  final Future<void> Function() onPressed;
  final IconData icon;
  final Duration debounceDuration;
  final double progressSize;
  final String? tooltip;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final running = asyncController.isRunning(actionKey);
      final button = IconButton(
        onPressed: running
            ? null
            : () async {
                await asyncController.run<void>(actionKey, onPressed);
              },
        style: style,
        icon: AnimatedSwitcher(
          duration: debounceDuration,
          child: running
              ? SizedBox(
                  key: const ValueKey('busy'),
                  width: progressSize,
                  height: progressSize,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, key: const ValueKey('idle')),
        ),
      );
      if (tooltip == null) return button;
      return Tooltip(message: tooltip!, child: button);
    });
  }
}

class ResponsiveTap extends StatelessWidget {
  const ResponsiveTap({
    super.key,
    required this.actionKey,
    required this.asyncController,
    required this.onTap,
    required this.child,
    this.tooltip,
  });

  final String actionKey;
  final AsyncActionController asyncController;
  final Future<void> Function() onTap;
  final Widget child;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final running = asyncController.isRunning(actionKey);
      final widget = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: running
            ? null
            : () async {
                await asyncController.run<void>(actionKey, onTap);
              },
        child: Stack(
          alignment: Alignment.center,
          children: [
            child,
            if (running)
              const Positioned.fill(
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ],
        ),
      );
      if (tooltip == null) return widget;
      return Tooltip(message: tooltip!, child: widget);
    });
  }
}
