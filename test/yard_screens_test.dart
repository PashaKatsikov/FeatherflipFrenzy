import 'package:featherflipfrenzygame/yardflow/infra/flip_pulse.dart';
import 'package:featherflipfrenzygame/yardflow/infra/yard_locker.dart';
import 'package:featherflipfrenzygame/yardflow/infra/yard_reach.dart';
import 'package:featherflipfrenzygame/yardflow/pages/quiet_yard_page.dart';
import 'package:featherflipfrenzygame/yardflow/pages/yard_invite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Size size, Widget child) {
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(home: child),
    );
  }

  final locker = YardLocker();
  final pulse = FlipPulse(locker, enabled: false);
  final reach = YardReach();

  testWidgets('permit portrait has Accept + Skip, no SafeArea on buttons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      wrap(
        const Size(390, 844),
        YardInvite(
          locker: locker,
          pulse: pulse,
          nextBuilder: (_) => const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.byType(SafeArea), findsNothing);
  });

  testWidgets('permit landscape keeps buttons centered without SafeArea', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2532, 1170);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      wrap(
        const Size(844, 390),
        YardInvite(
          locker: locker,
          pulse: pulse,
          nextBuilder: (_) => const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.byType(SafeArea), findsNothing);
  });

  testWidgets('nowifi portrait and landscape show Retry via retryBuilder', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      wrap(
        const Size(390, 844),
        QuietYardPage(
          reach: reach,
          retryBuilder: (_) => const Scaffold(body: Text('retry-target')),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('NO INTERNET CONNECTION'), findsOneWidget);
    expect(find.text('Check your connection and try again'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.byType(SafeArea), findsNothing);

    tester.view.physicalSize = const Size(2532, 1170);
    await tester.pumpWidget(
      wrap(
        const Size(844, 390),
        QuietYardPage(
          reach: reach,
          retryBuilder: (_) => const Scaffold(body: Text('retry-target')),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('NO INTERNET CONNECTION'), findsOneWidget);
    expect(find.text('Check your connection and try again'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
