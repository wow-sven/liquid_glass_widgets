import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  setUp(() => GlassNavigationShellState.debugPinningSupported = true);
  tearDown(() => GlassNavigationShellState.debugPinningSupported = null);

  testWidgets('replacing a header cannot unregister its successor',
      (tester) async {
    final version = ValueNotifier(0);
    addTearDown(version.dispose);
    late GlassNavigationShellState shell;
    late ModalRoute<dynamic> route;
    var hoisted = false;
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      builder: (_, child) => GlassNavigationShell(child: child!),
      home: Builder(builder: (context) {
        shell = GlassNavigationShell.maybeOf(context)!;
        route = ModalRoute.of(context)!;
        return ValueListenableBuilder<int>(
          valueListenable: version,
          builder: (_, value, child) => Scaffold(
            body: value < 0
                ? const SizedBox()
                : GlassPinnedBarChrome(
                    key: ValueKey(value),
                    actions: [
                      GlassBarItem.icon(
                        icon: const Icon(Icons.done),
                        label: 'Done $value',
                        onTap: () => taps++,
                      ),
                    ],
                    builder: (_, chrome) {
                      hoisted = chrome.hoisted;
                      return Row(children: chrome.actions);
                    },
                  ),
          ),
        );
      }),
    ));
    await tester.pumpAndSettle();
    for (var i = 1; i <= 3; i++) {
      version.value = i;
      await tester.pumpAndSettle();
      expect(shell.isHoisting(route), isTrue);
      expect(hoisted, isTrue);
      expect(shell.resolveState()!.settled, isTrue);
      expect(find.bySemanticsLabel('Done $i').hitTestable(), findsOneWidget);
      await tester.tap(find.byIcon(Icons.done).hitTestable());
      await tester.pumpAndSettle();
      expect(taps, i);
    }
    version.value = -1;
    await tester.pumpAndSettle();
    expect(shell.isHoisting(route), isFalse);
    expect(find.byIcon(Icons.done), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unregistered disabled header cannot release another header',
      (tester) async {
    final showDisabled = ValueNotifier(false);
    addTearDown(showDisabled.dispose);
    late GlassNavigationShellState shell;
    late ModalRoute<dynamic> route;
    await tester.pumpWidget(MaterialApp(
      builder: (_, child) => GlassNavigationShell(child: child!),
      home: Builder(builder: (context) {
        shell = GlassNavigationShell.maybeOf(context)!;
        route = ModalRoute.of(context)!;
        return ValueListenableBuilder<bool>(
          valueListenable: showDisabled,
          builder: (_, show, child) => Column(children: [
            GlassPinnedBarChrome(
              key: const ValueKey('active'),
              actions: [
                GlassBarItem.icon(
                  icon: const Icon(Icons.done),
                  label: 'Done',
                  onTap: () {},
                )
              ],
              builder: (_, chrome) => Row(children: chrome.actions),
            ),
            if (show)
              GlassPinnedBarChrome(
                enabled: false,
                builder: (_, chrome) => const SizedBox(),
              ),
          ]),
        );
      }),
    ));
    await tester.pumpAndSettle();
    showDisabled.value = true;
    await tester.pumpAndSettle();
    expect(shell.isHoisting(route), isTrue);
    showDisabled.value = false;
    await tester.pumpAndSettle();
    expect(shell.isHoisting(route), isTrue);
    expect(tester.takeException(), isNull);
  });
}
