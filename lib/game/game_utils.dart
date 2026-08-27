import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Rect, Offset;

Vector2 offsetToVector(Offset o) => Vector2(o.dx, o.dy);

bool rectContainsVector(Rect r, Vector2 v) =>
    v.x >= r.left && v.x <= r.right && v.y >= r.top && v.y <= r.bottom;

double clampD(double value, double min, double max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

/// Moves [current] towards [target] by at most [maxDelta], returning the new
/// value. Used for frame-rate independent acceleration/deceleration.
Vector2 moveToward(Vector2 current, Vector2 target, double maxDelta) {
  final diff = target - current;
  final dist = diff.length;
  if (dist <= maxDelta || dist == 0) {
    return target.clone();
  }
  return current + diff * (maxDelta / dist);
}
