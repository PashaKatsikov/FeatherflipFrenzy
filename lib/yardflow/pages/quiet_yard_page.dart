import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../infra/yard_reach.dart';

class QuietYardPage extends StatefulWidget {
  const QuietYardPage({
    super.key,
    required this.reach,
    required this.retryBuilder,
  });

  final YardReach reach;
  final WidgetBuilder retryBuilder;

  @override
  State<QuietYardPage> createState() => _QuietYardPageState();
}

class _QuietYardPageState extends State<QuietYardPage> {
  bool _checking = false;
  bool _stillOffline = false;

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

  Future<void> _retry() async {
    if (_checking) return;
    HapticFeedback.lightImpact();
    setState(() {
      _checking = true;
      _stillOffline = false;
    });
    bool online = false;
    try {
      online = await widget.reach.canReachNetwork();
    } catch (_) {
      online = false;
    }
    if (!mounted) return;
    if (online) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: widget.retryBuilder),
      );
      return;
    }
    setState(() {
      _checking = false;
      _stillOffline = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final landscape = media.orientation == Orientation.landscape;
    final width = landscape
        ? (media.size.width * 0.40).clamp(300.0, 520.0)
        : (media.size.width * 0.66).clamp(260.0, 420.0);
    final height = landscape ? 70.0 : 74.0;
    final titleSize = landscape ? 26.0 : 28.0;
    final bodySize = landscape ? 16.0 : 17.0;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFF2E7A2C),
              Color(0xFF1F4F1E),
            ],
          ),
        ),
        child: SizedBox.expand(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'NO INTERNET CONNECTION',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    color: Colors.white,
                    fontSize: titleSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Check your connection and try again',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: bodySize,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                SizedBox(height: landscape ? 28 : 36),
                _RetryButton(
                  width: width,
                  height: height,
                  busy: _checking,
                  onTap: _retry,
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 195),
                  child: _stillOffline
                      ? const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'No connection yet',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  const _RetryButton({
    required this.width,
    required this.height,
    required this.busy,
    required this.onTap,
  });

  final double width;
  final double height;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFFFFCC45), Color(0xFFFF762D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(color: const Color(0xFF61301C), width: 3),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 5)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(34),
            onTap: busy ? null : onTap,
            child: Center(
              child: busy
                  ? const SizedBox.square(
                      dimension: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.8,
                        color: Color(0xFF422014),
                      ),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.refresh_rounded,
                          color: Color(0xFF422014),
                          size: 28,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Retry',
                          style: TextStyle(
                            fontFamily: 'Fredoka',
                            color: Color(0xFF422014),
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
