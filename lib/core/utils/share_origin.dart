import 'package:flutter/widgets.dart';

/// share_plus requires a non-empty popover anchor on iPad.
Rect shareOriginFor(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is RenderBox && renderObject.hasSize) {
    final origin = renderObject.localToGlobal(Offset.zero);
    final rect = origin & renderObject.size;
    if (rect.width > 0 && rect.height > 0) return rect;
  }
  return const Rect.fromLTWH(1, 1, 1, 1);
}
