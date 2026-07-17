import 'dart:math' as math;

class NormalizedPoint {
  const NormalizedPoint(this.x, this.y);

  final double x;
  final double y;

  NormalizedPoint clamp() =>
      NormalizedPoint(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0));
}

class DocumentQuad {
  const DocumentQuad({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  const DocumentQuad.inset()
    : topLeft = const NormalizedPoint(0.04, 0.04),
      topRight = const NormalizedPoint(0.96, 0.04),
      bottomRight = const NormalizedPoint(0.96, 0.96),
      bottomLeft = const NormalizedPoint(0.04, 0.96);

  final NormalizedPoint topLeft;
  final NormalizedPoint topRight;
  final NormalizedPoint bottomRight;
  final NormalizedPoint bottomLeft;

  List<NormalizedPoint> get points => [
    topLeft,
    topRight,
    bottomRight,
    bottomLeft,
  ];

  DocumentQuad update(int index, NormalizedPoint point) {
    final safe = point.clamp();
    return DocumentQuad(
      topLeft: index == 0 ? safe : topLeft,
      topRight: index == 1 ? safe : topRight,
      bottomRight: index == 2 ? safe : bottomRight,
      bottomLeft: index == 3 ? safe : bottomLeft,
    );
  }

  bool get isValid {
    double cross(NormalizedPoint a, NormalizedPoint b, NormalizedPoint c) {
      return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
    }

    final signs = <double>[
      cross(topLeft, topRight, bottomRight),
      cross(topRight, bottomRight, bottomLeft),
      cross(bottomRight, bottomLeft, topLeft),
      cross(bottomLeft, topLeft, topRight),
    ];
    return signs.every((value) => value > 0) && area > 0.08;
  }

  double get area {
    final p = points;
    var sum = 0.0;
    for (var i = 0; i < p.length; i++) {
      final next = p[(i + 1) % p.length];
      sum += p[i].x * next.y - next.x * p[i].y;
    }
    return sum.abs() / 2;
  }

  double widthFor(int imageWidth, int imageHeight) {
    double distance(NormalizedPoint a, NormalizedPoint b) => math.sqrt(
      math.pow((a.x - b.x) * imageWidth, 2) +
          math.pow((a.y - b.y) * imageHeight, 2),
    );
    return (distance(topLeft, topRight) + distance(bottomLeft, bottomRight)) /
        2;
  }

  double heightFor(int imageWidth, int imageHeight) {
    double distance(NormalizedPoint a, NormalizedPoint b) => math.sqrt(
      math.pow((a.x - b.x) * imageWidth, 2) +
          math.pow((a.y - b.y) * imageHeight, 2),
    );
    return (distance(topLeft, bottomLeft) + distance(topRight, bottomRight)) /
        2;
  }
}
