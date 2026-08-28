import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/flip_gate_config.dart';
import '../infra/flip_pulse.dart';
import '../infra/yard_locker.dart';

class YardInvite extends StatefulWidget {
  const YardInvite({
    super.key,
    required this.locker,
    required this.pulse,
    required this.nextBuilder,
  });

  final YardLocker locker;
  final FlipPulse pulse;
  final WidgetBuilder nextBuilder;

  @override
  State<YardInvite> createState() => _YardInviteState();
}

class _YardInviteState extends State<YardInvite> {
  bool _working = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _accept() async {
    if (_working) return;
    setState(() => _working = true);
    await widget.pulse.askPermission();
    await widget.locker.markInviteSettled();
    _continue();
  }

  Future<void> _skip() async {
    if (_working) return;
    setState(() => _working = true);
    await _snooze();
    _continue();
  }

  Future<void> _snooze() {
    final until = DateTime.now().millisecondsSinceEpoch ~/ 1000 +
        FlipGateConfig.pushSnoozeSeconds;
    return widget.locker.snoozePushInvite(until);
  }

  void _continue() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: widget.nextBuilder),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final landscape = media.orientation == Orientation.landscape;
    final background = landscape
        ? 'assets/Featherflip_Frenzy_additional_assets/'
            'Horizontal_Notifications_Screen.webp'
        : 'assets/Featherflip_Frenzy_additional_assets/'
            'Vertical_Notifications_Screen.webp';
    final portraitWidth = (media.size.width * 0.80).clamp(280.0, 440.0);
    final landscapeWidth =
        (media.size.width * 0.42).clamp(320.0, 560.0) * 0.70;
    final acceptH = landscape ? 66.0 : 74.0;
    final skipH = landscape ? 66.0 : 64.0;

    final accept = _InviteButton(
      width: landscape ? landscapeWidth : portraitWidth,
      height: acceptH,
      fontSize: landscape ? 22.0 : 25.0,
      label: 'Accept',
      emphasized: true,
      busy: _working,
      onTap: _accept,
    );
    final skip = _InviteButton(
      width: landscape ? landscapeWidth : portraitWidth * 0.9,
      height: skipH,
      fontSize: 22.0,
      label: 'Skip',
      emphasized: false,
      busy: false,
      onTap: _skip,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            background,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
          Align(
            alignment: Alignment(0, landscape ? 0.80 : 0.90),
            child: landscape
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      accept,
                      const SizedBox(width: 18),
                      skip,
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      accept,
                      const SizedBox(height: 16),
                      skip,
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _InviteButton extends StatelessWidget {
  const _InviteButton({
    required this.width,
    required this.height,
    required this.fontSize,
    required this.label,
    required this.emphasized,
    required this.busy,
    required this.onTap,
  });

  final double width;
  final double height;
  final double fontSize;
  final String label;
  final bool emphasized;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = height / 2;
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            colors: emphasized
                ? const <Color>[Color(0xFFFFCF4A), Color(0xFFFF7D2C)]
                : const <Color>[Color(0xFFFFA63D), Color(0xFFD94A2A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(color: const Color(0xFF6E301B), width: 3),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Colors.black45,
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: busy ? null : onTap,
            child: Center(
              child: busy
                  ? const SizedBox.square(
                      dimension: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: Color(0xFF4A2315),
                      ),
                    )
                  : Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        color: const Color(0xFF3D1C12),
                        fontSize: fontSize,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        height: 1.0,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
