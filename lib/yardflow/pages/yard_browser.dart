import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../infra/flip_agent.dart';
import '../infra/flip_pulse.dart';
import '../infra/flip_tap_bridge.dart';
import '../infra/flip_trace.dart';
import '../infra/yard_locker.dart';
import '../infra/yard_reach.dart';
import 'quiet_yard_page.dart';

class YardBrowser extends StatefulWidget {
  const YardBrowser({
    super.key,
    required this.url,
    required this.locker,
    required this.reach,
    required this.pulse,
    required this.agent,
    this.coldLaunch = false,
  });

  final String url;
  final YardLocker locker;
  final YardReach reach;
  final FlipPulse pulse;
  final FlipAgent agent;
  final bool coldLaunch;

  @override
  State<YardBrowser> createState() => _YardBrowserState();
}

class _YardBrowserState extends State<YardBrowser> with WidgetsBindingObserver {
  late final WebViewController _controller;
  StreamSubscription<List<ConnectivityResult>>? _networkSubscription;
  bool _viewportReady = false;
  bool _offlineShown = false;
  int _redirectAttempts = 0;
  String? _lastMainUrl;
  Timer? _metricsDebounce;
  Size? _lastMetricsSize;

  /// Recovery tries after WebKit reports `-1007`. Not 3 (template) and not 1
  /// (the uniqueness pass that left long affiliate chains dead).
  static const int _redirectRetryBudget = 4;

  /// Hops kept in one WebKit navigation. Cap is ~20; restart before that.
  static const int _laneHopCap = 12;

  /// Total hops across restarts. Past this it is a loop, not a long chain.
  static const int _laneHopCeiling = 96;

  /// Let the `prevent` decision land before the replacement load starts.
  static const Duration _laneHandover = Duration(milliseconds: 31);

  static const Set<String> _inPageSchemes = <String>{
    'http',
    'https',
    'about',
    'data',
    'blob',
  };

  void Function(String url)? _onLiveDestination;

  /// WebKit drops a `loadRequest` issued while the content process is
  /// suspended, so a tap that lands before the app is active waits here.
  String? _deferredHref;

  /// Target handed to WebKit but not yet acknowledged by `onPageStarted`.
  /// The push hold stays on disk until that acknowledgement arrives.
  String? _awaitingConfirm;

  Timer? _laneTimer;

  /// Secure twin currently being tried -> the plain `http` hop it replaced.
  final Map<String, String> _downgradeFallback = <String, String>{};
  final Set<String> _downgradeTried = <String>{};

  String? _laneRoot;
  bool _inFlight = false;
  bool _jarCleared = false;
  int _hopsThisLane = 0;
  int _hopsWholeChain = 0;
  bool _cuttingLane = false;

  static const List<int> _reflowBeats = <int>[47, 168, 292, 581, 844];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enterImmersive();
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    final params = Platform.isIOS
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          )
        : const PlatformWebViewControllerCreationParams();
    _controller = WebViewController.fromPlatformCreationParams(
      params,
      onPermissionRequest: (request) => request.grant(),
    )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(widget.agent.userAgent)
      ..enableZoom(false)
      ..setNavigationDelegate(_navigation());
    if (_controller.platform is WebKitWebViewController) {
      (_controller.platform as WebKitWebViewController)
          .setAllowsBackForwardNavigationGestures(true);
    }

    _onLiveDestination = (url) {
      final uri = Uri.tryParse(url);
      if (mounted && uri != null && uri.hasScheme) {
        unawaited(_openHref(uri, fresh: true));
      }
    };
    widget.pulse.onDestination = _onLiveDestination;
    _networkSubscription = widget.reach.changes.listen((states) {
      if (states.every((state) => state == ConnectivityResult.none)) {
        // iOS reports `none` mid hand-off while traffic still flows, so the
        // radio state only prompts a check — it never decides on its own.
        unawaited(_showOfflineAfterProbe());
      }
    });

    if (widget.coldLaunch) {
      _settleColdViewport();
    } else {
      _viewportReady = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_loadAfterLayout());
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePending());
  }

  void _enterImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _settleColdViewport() async {
    _enterImmersive();
    await Future<void>.delayed(const Duration(milliseconds: 247));
    if (!mounted) return;
    setState(() => _viewportReady = true);
    await _loadAfterLayout();
  }

  /// Wait until WKWebView has a real frame. Loading in initState (size 0)
  /// is what made partner pages paint the wrong box for a couple of seconds.
  Future<void> _loadAfterLayout() async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _openHref(Uri.parse(widget.url), fresh: true);
  }

  static bool get _backgrounded {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
  }

  /// [fresh] marks an entry point (first load, push tap) rather than a hop
  /// inside a running chain, so no leftover lane state can distort it.
  Future<void> _openHref(Uri uri, {bool fresh = false}) async {
    final target = uri.toString();
    if (_backgrounded) {
      flipTrace(() => '[FF.COOP] deferred while background: $target');
      _deferredHref = target;
      return;
    }
    flipTrace(() => '[FF.COOP] load fresh=$fresh $target');
    if (fresh) {
      _laneTimer?.cancel();
      _cuttingLane = false;
      _redirectAttempts = 0;
    }
    if (!_cuttingLane) {
      _laneRoot = target;
      _hopsThisLane = 0;
      _hopsWholeChain = 0;
    }
    _awaitingConfirm = target;
    _inFlight = true;
    await _controller.loadRequest(uri);
  }

  /// WebKit really started the navigation, so the hold has done its job.
  Future<void> _confirmStarted() async {
    final target = _awaitingConfirm;
    _awaitingConfirm = null;
    if (target == null) return;
    final held = await widget.locker.peekPushUrl();
    if (held == target) await widget.locker.clearPushUrl();
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    setState(() {});
    final view = View.of(context);
    final size = view.physicalSize;
    final rotated = _lastMetricsSize != null &&
        ((_lastMetricsSize!.width < _lastMetricsSize!.height) !=
            (size.width < size.height));
    _lastMetricsSize = size;
    if (!rotated) return;
    _enterImmersive();
    _metricsDebounce?.cancel();
    _pokeReflow(_reflowBeats);
  }

  void _pokeReflow(List<int> delaysMs) {
    for (final ms in delaysMs) {
      Timer(Duration(milliseconds: ms), () {
        if (!mounted) return;
        _controller
            .runJavaScript(
              'if(document.documentElement)document.documentElement.style.zoom="1";'
              'if(window.__ffCoopTint)window.__ffCoopTint();'
              'window.dispatchEvent(new Event("orientationchange"));'
              'window.dispatchEvent(new Event("resize"));'
              'if(window.visualViewport)'
              '  window.visualViewport.dispatchEvent(new Event("resize"));',
            )
            .catchError((_) {});
      });
    }
    _metricsDebounce = Timer(const Duration(milliseconds: 385), () {
      if (!mounted) return;
      _installYardShell();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _enterImmersive();
      unawaited(_resumeWork());
    }
  }

  Future<void> _resumeWork() async {
    final deferred = _deferredHref;
    _deferredHref = null;
    if (deferred != null) {
      final uri = Uri.tryParse(deferred);
      if (mounted && uri != null && uri.hasScheme) {
        await _openHref(uri, fresh: true);
        return;
      }
    }
    await _consumePending();
  }

  /// A native tap always wins; a surviving hold means an earlier tap never
  /// reached WebKit, so it is re-issued instead of being dropped.
  Future<void> _consumePending() async {
    final tapped = await FlipTapBridge.consume();
    final target = tapped ?? await widget.locker.peekPushUrl();
    if (target == null || target.isEmpty) return;
    flipTrace(() => '[FF.COOP] resume pending tap=${tapped != null} $target');
    if (target == _awaitingConfirm || target == _deferredHref) return;
    if (tapped == null && target == _lastMainUrl) {
      await widget.locker.clearPushUrl();
      return;
    }
    await widget.locker.persistPushDestination(target);
    final uri = Uri.tryParse(target);
    if (mounted && uri != null && uri.hasScheme) {
      await _openHref(uri, fresh: true);
    }
  }

  NavigationDelegate _navigation() {
    return NavigationDelegate(
      onPageStarted: (url) {
        flipTrace(() => '[FF.COOP] started $url');
        _lastMainUrl = url;
        _inFlight = true;
        unawaited(_confirmStarted());
        _installYardShell();
      },
      onPageFinished: (url) {
        flipTrace(() => '[FF.COOP] finished $url');
        _redirectAttempts = 0;
        _jarCleared = false;
        _inFlight = false;
        _hopsThisLane = 0;
        _hopsWholeChain = 0;
        _cuttingLane = false;
        _installYardShell();
        Future<void>.delayed(const Duration(milliseconds: 1130), () async {
          if (!mounted) return;
          setState(() {});
          await _controller.runJavaScript(
            'if(document.documentElement)document.documentElement.style.zoom="1";'
            'if(window.__ffCoopTint)window.__ffCoopTint();'
            'window.dispatchEvent(new Event("resize"));'
            'window.visualViewport?.dispatchEvent(new Event("resize"));',
          );
        });
      },
      onWebResourceError: (error) {
        flipTrace(
          () => '[FF.COOP] weberror code=${error.errorCode} '
              'main=${error.isForMainFrame} url=${error.url} '
              '${error.description}',
        );
        // `-999` is a load we replaced ourselves; `102` is WebKit reporting
        // the `prevent` this delegate just returned for a lane cut or a
        // protocol swap. Neither is a failure, and neither says anything
        // about the connection.
        if (error.errorCode == -999 || error.errorCode == 102) return;
        final mainFrame = error.isForMainFrame ?? true;
        final lower = error.description.toLowerCase();
        final redirectLoop = error.errorCode == -1007 ||
            lower.contains('too_many_redirects') ||
            lower.contains('too many redirects');
        _inFlight = false;
        if (redirectLoop) {
          unawaited(_recoverFromRedirectLoop());
          return;
        }
        if (!mainFrame) return;
        final stalled = _awaitingConfirm;
        _awaitingConfirm = null;
        final fallback = _plainFallbackFor(stalled ?? _lastMainUrl);
        if (fallback != null) {
          flipTrace(() => '[FF.COOP] secure twin failed, plain $fallback');
          unawaited(_openHref(fallback, fresh: true));
          return;
        }
        unawaited(_showOfflineAfterProbe());
      },
      onNavigationRequest: (request) {
        final uri = Uri.tryParse(request.url);
        if (uri == null) {
          final webShaped = request.url.startsWith('http://') ||
              request.url.startsWith('https://');
          if (!webShaped) return NavigationDecision.prevent;
          if (request.isMainFrame) _lastMainUrl = request.url;
          return NavigationDecision.navigate;
        }
        if (uri.scheme == 'javascript') return NavigationDecision.prevent;
        if (!_inPageSchemes.contains(uri.scheme)) {
          launchUrl(uri, mode: LaunchMode.externalApplication);
          return NavigationDecision.prevent;
        }
        if (request.isMainFrame) {
          if (uri.scheme == 'about' && _lastMainUrl != null) {
            return NavigationDecision.prevent;
          }
          final upgrade = _swapDowngrade(uri);
          if (upgrade != null) return upgrade;
          final split = _trackMainFrameHop(request.url, uri);
          if (split != null) return split;
        }
        return NavigationDecision.navigate;
      },
    );
  }

  /// A main-frame hop from `https` down to plain `http` wedges WebKit: the
  /// navigation stays provisional forever and no error is ever delivered.
  /// The secure twin of the target is tried first; the plain hop is kept as
  /// a fallback for when that twin genuinely fails.
  NavigationDecision? _swapDowngrade(Uri target) {
    if (target.scheme != 'http') return null;
    final from = _lastMainUrl;
    if (from == null || !from.startsWith('https:')) return null;
    final plain = target.toString();
    if (!_downgradeTried.add(plain)) return null;
    final secure = target.replace(scheme: 'https');
    _downgradeFallback[secure.toString()] = plain;
    flipTrace(() => '[FF.COOP] downgrade to http, trying $secure');
    _laneTimer?.cancel();
    _laneTimer = Timer(_laneHandover, () {
      if (mounted) unawaited(_openHref(secure, fresh: true));
    });
    return NavigationDecision.prevent;
  }

  Uri? _plainFallbackFor(String? url) {
    if (url == null) return null;
    final plain = _downgradeFallback.remove(url);
    return plain == null ? null : Uri.tryParse(plain);
  }

  /// WKWebView aborts a single navigation with `-1007` after ~20 server
  /// redirects. Affiliate chains are routinely longer. Reloading the last
  /// hop cannot help: the chain is long, not looping. Re-issuing the next
  /// hop as a fresh `loadRequest` resets WebKit's counter and keeps cookies.
  NavigationDecision? _trackMainFrameHop(String url, Uri target) {
    _lastMainUrl = url;
    final continuing = _cuttingLane;
    _cuttingLane = false;
    if (!continuing && !_inFlight) {
      _laneRoot = url;
      _hopsThisLane = 0;
      _hopsWholeChain = 0;
      return null;
    }
    _hopsThisLane++;
    _hopsWholeChain++;
    if (_hopsWholeChain >= _laneHopCeiling) return null;
    if (_hopsThisLane < _laneHopCap) return null;
    _hopsThisLane = 0;
    _cuttingLane = true;
    _laneTimer?.cancel();
    _laneTimer = Timer(_laneHandover, () {
      if (mounted) unawaited(_openHref(target));
    });
    return NavigationDecision.prevent;
  }

  Future<void> _recoverFromRedirectLoop() async {
    if (!mounted || _offlineShown) return;
    final target = _laneRoot ?? _lastMainUrl ?? widget.url;
    final parsed = Uri.tryParse(target);
    _hopsThisLane = 0;
    _hopsWholeChain = 0;
    _cuttingLane = false;
    if (parsed != null && _redirectAttempts < _redirectRetryBudget) {
      _redirectAttempts++;
      if (_redirectAttempts == _redirectRetryBudget && !_jarCleared) {
        _jarCleared = true;
        try {
          await WebViewCookieManager().clearCookies();
        } catch (_) {}
      }
      if (!mounted) return;
      await _openHref(parsed);
      return;
    }
    _redirectAttempts = 0;
    if (await _controller.canGoBack()) {
      if (!mounted) return;
      await _controller.goBack();
      return;
    }
    final entry = Uri.tryParse(widget.url);
    if (!mounted) return;
    if (entry != null && target != widget.url) {
      await _openHref(entry);
      return;
    }
    await _showOfflineAfterProbe();
  }

  /// The only route to the offline screen. A page can fail for a hundred
  /// reasons that have nothing to do with the connection, so the verdict
  /// always comes from a live probe rather than from the failure itself.
  Future<void> _showOfflineAfterProbe() async {
    if (_offlineShown) return;
    bool online = true;
    try {
      online = await widget.reach.canReachNetwork();
    } catch (_) {
      online = false;
    }
    if (online || !mounted) return;
    await _goOffline();
  }

  Future<void> _goOffline() async {
    if (_offlineShown || !mounted) return;
    _offlineShown = true;
    String current;
    try {
      current = await _controller.currentUrl() ?? widget.url;
    } catch (_) {
      current = widget.url;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => QuietYardPage(
          reach: widget.reach,
          retryBuilder: (_) => YardBrowser(
            url: current,
            locker: widget.locker,
            reach: widget.reach,
            pulse: widget.pulse,
            agent: widget.agent,
          ),
        ),
      ),
    );
  }

  /// Single merged shell: insets, zoom lock, tap polish, keyboard lift,
  /// focus scale, farmyard scrollbar, plus a unique selection tint.
  /// Inline media is native-only.
  void _installYardShell() {
    _controller.runJavaScript(r'''
(function(){
  var win = window;
  var tag = 'ff-coop-skin';
  var rules = [
    ':root{--safe-area-inset-top:0px!important;--safe-area-inset-right:0px!important;',
    '--safe-area-inset-bottom:0px!important;--safe-area-inset-left:0px!important;',
    '--sat:0px!important;--sar:0px!important;--sab:0px!important;--sal:0px!important;',
    '--safe-top:0px!important;--safe-right:0px!important;',
    '--safe-bottom:0px!important;--safe-left:0px!important;}',
    'html,body{overscroll-behavior:none!important;overscroll-behavior-y:none!important;',
    '-webkit-text-size-adjust:100%!important;text-size-adjust:100%!important;}',
    '*{-webkit-tap-highlight-color:transparent!important;}',
    '*:not(input):not(textarea):not([contenteditable="true"]){-webkit-touch-callout:none!important;}',
    'input,textarea,select,[contenteditable="true"]{font-size:max(16px,1em)!important;caret-color:#B8752C;}',
    'html{-webkit-overflow-scrolling:touch;}',
    '::-webkit-scrollbar{width:6px;height:6px;}',
    '::-webkit-scrollbar-thumb{background:#B8752C;border-radius:5px;}',
    '::selection{background:#E8C48A;color:#3A2410;}',
    'img{-webkit-user-drag:none;}'
  ].join('');
  function kbOpen(){
    var vv = win.visualViewport;
    return !!vv && vv.height < win.innerHeight * 0.72;
  }
  function pinMeta(){
    var host = document.head || document.documentElement;
    if (!host) return;
    var node = document.querySelector('meta[name="viewport"]');
    if (!node) {
      node = document.createElement('meta');
      node.name = 'viewport';
      host.appendChild(node);
    }
    node.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no, viewport-fit=contain';
  }
  function tint(){
    if (kbOpen()) return;
    var host = document.head || document.documentElement;
    if (!host) return;
    if (document.documentElement) document.documentElement.style.zoom = '1';
    pinMeta();
    var style = document.getElementById(tag);
    if (!style) {
      style = document.createElement('style');
      style.id = tag;
      host.appendChild(style);
    }
    style.textContent = rules;
  }
  win.__ffCoopTint = tint;
  if (win.__ffCoopReady) { tint(); return; }
  win.__ffCoopReady = 1;
  function afterNav(){
    win.setTimeout(tint, 220);
    win.setTimeout(tint, 740);
  }
  var hist = history;
  var wrap = function(fn){
    return function(){
      var out = fn.apply(this, arguments);
      afterNav();
      return out;
    };
  };
  hist.pushState = wrap(hist.pushState);
  hist.replaceState = wrap(hist.replaceState);
  win.addEventListener('popstate', afterNav);
  function stopZoom(evt){ evt.preventDefault(); }
  document.addEventListener('gesturestart', stopZoom, {passive:false});
  document.addEventListener('gesturechange', stopZoom, {passive:false});
  document.addEventListener('gestureend', stopZoom, {passive:false});
  document.addEventListener('touchmove', function(evt){
    if (evt.scale !== undefined && evt.scale !== 1) evt.preventDefault();
  }, {passive:false});
  var prior = 0;
  document.addEventListener('touchend', function(evt){
    var stamp = Date.now();
    if (stamp - prior <= 280) evt.preventDefault();
    prior = stamp;
  }, {passive:false});
  function isField(el){
    return !!el && el.matches && el.matches('input, textarea, select, [contenteditable="true"]');
  }
  document.addEventListener('focusin', function(evt){
    if (!isField(evt.target)) return;
    win.setTimeout(function(){
      evt.target.scrollIntoView({behavior:'auto', block:'nearest'});
    }, 280);
  }, true);
  tint();
  win.setInterval(tint, 2800);
})();
''');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _metricsDebounce?.cancel();
    _laneTimer?.cancel();
    _networkSubscription?.cancel();
    if (widget.pulse.onDestination == _onLiveDestination) {
      widget.pulse.onDestination = null;
    }
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).viewPadding;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await _controller.canGoBack()) {
          await _controller.goBack();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: !_viewportReady
            ? const ColoredBox(color: Colors.black)
            : Padding(
                padding: EdgeInsets.only(
                  top: safe.top,
                  bottom: safe.bottom,
                  left: safe.left,
                  right: safe.right,
                ),
                child: SizedBox.expand(
                  child: WebViewWidget(controller: _controller),
                ),
              ),
      ),
    );
  }
}
