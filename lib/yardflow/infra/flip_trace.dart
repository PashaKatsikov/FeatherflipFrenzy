import 'package:flutter/foundation.dart';

void flipTrace(String Function() message) {
  assert(() { debugPrint(message()); return true; }());
}
