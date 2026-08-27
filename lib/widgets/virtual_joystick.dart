import 'package:flutter/material.dart';

/// Fixed virtual joystick. Direction is binary (deadzone aside): the chicken
/// always runs at one speed so a light touch and a hard push feel the same.
class VirtualJoystick extends StatefulWidget {
  final ValueChanged<Offset> onDirection;
  final VoidCallback onFlick;
  final VoidCallback onRelease;

  const VirtualJoystick({
    super.key,
    required this.onDirection,
    required this.onFlick,
    required this.onRelease,
  });

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  static const double _size = 148;
  static const double _baseRadius = 64;
  static const double _knobRadius = 26;
  static const double _maxThrow = 42;
  static const double _deadzone = 12;
  static const double _flickDelta = 22;

  Offset _knob = Offset.zero;
  bool _held = false;
  bool _flickedThisGesture = false;

  Offset get _center => const Offset(_size / 2, _size / 2);

  void _handlePoint(Offset local, {required bool isMove}) {
    final raw = local - _center;
    final dist = raw.distance;
    Offset knob;
    if (dist <= 0) {
      knob = Offset.zero;
    } else if (dist > _maxThrow) {
      knob = raw / dist * _maxThrow;
    } else {
      knob = raw;
    }

    if (isMove && !_flickedThisGesture && (local - (_center + _knob)).distance >= _flickDelta) {
      _flickedThisGesture = true;
      widget.onFlick();
    }

    setState(() {
      _held = true;
      _knob = knob;
    });

    if (knob.distance < _deadzone) {
      widget.onDirection(Offset.zero);
    } else {
      widget.onDirection(knob / knob.distance);
    }
  }

  void _release() {
    setState(() {
      _held = false;
      _knob = Offset.zero;
      _flickedThisGesture = false;
    });
    widget.onRelease();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) => _handlePoint(d.localPosition, isMove: false),
        onPanUpdate: (d) => _handlePoint(d.localPosition, isMove: true),
        onPanEnd: (_) => _release(),
        onPanCancel: _release,
        child: CustomPaint(
          painter: _JoystickPainter(knob: _knob, held: _held, baseRadius: _baseRadius, knobRadius: _knobRadius, maxThrow: _maxThrow),
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  _JoystickPainter({
    required this.knob,
    required this.held,
    required this.baseRadius,
    required this.knobRadius,
    required this.maxThrow,
  });

  final Offset knob;
  final bool held;
  final double baseRadius;
  final double knobRadius;
  final double maxThrow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    canvas.drawCircle(
      center,
      baseRadius,
      Paint()..color = Color.fromRGBO(0, 0, 0, held ? 0.62 : 0.50),
    );
    canvas.drawCircle(
      center,
      baseRadius,
      Paint()
        ..color = const Color(0xFFD9A971)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
      center,
      maxThrow,
      Paint()
        ..color = Color.fromRGBO(255, 255, 255, held ? 0.20 : 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final knobCenter = center + knob;
    canvas.drawCircle(knobCenter, knobRadius + 2, Paint()..color = const Color(0xFFFFE08A));
    canvas.drawCircle(
      knobCenter,
      knobRadius,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFC93C), Color(0xFFE89A12)],
          center: Alignment(-0.3, -0.4),
        ).createShader(Rect.fromCircle(center: knobCenter, radius: knobRadius)),
    );
    canvas.drawCircle(
      knobCenter,
      knobRadius,
      Paint()
        ..color = Colors.white70
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter old) => old.knob != knob || old.held != held;
}
