import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:liquid_glass_widgets/widgets/surfaces/shared/glass_nav_pinned_host.dart';

void main() {
  setUp(() => GlassNavigationShellState.debugPinningSupported = true);
  tearDown(() => GlassNavigationShellState.debugPinningSupported = null);

  testWidgets('one shell follows outer flow and inner page transitions',
      (tester) async {
    final shell = GlobalKey<GlassNavigationShellState>();
    final outer = GlobalKey<NavigatorState>();
    final inner = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_app(shell, outer, const _Header('List')));
    await tester.pumpAndSettle();
    final flow = _route(_nested(inner, const _Header('Create')));
    outer.currentState!.push(flow);
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final state = shell.currentState!.resolveState()!;
      expect(state.from.titleContentKey, 'List');
      expect(state.to.titleContentKey, 'Create');
      expect(state.progress, closeTo(flow.animation!.value, .0001));
      expect(state.settled, isFalse);
    }
    await tester.pumpAndSettle();
    expect(find.byType(GlassNavigationShell), findsOneWidget);
    expect(shell.currentState!.resolveState()!.settled, isTrue);

    final editor = _route(const _Header('Editor'));
    inner.currentState!.pushReplacement(editor);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    var state = shell.currentState!.resolveState()!;
    expect(state.from.titleContentKey, 'Create');
    expect(state.to.titleContentKey, 'Editor');
    expect(state.progress, closeTo(editor.animation!.value, .0001));
    await tester.pumpAndSettle();
    final phase = _route(const _Header('Phase'));
    inner.currentState!.push(phase);
    await tester.pumpAndSettle();
    // The default back callback must target the header's inner Navigator.
    await tester.tap(find.byIcon(CupertinoIcons.back).hitTestable());
    await tester.pumpAndSettle();
    expect(shell.currentState!.resolveState()!.to.titleContentKey, 'Editor');

    outer.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    state = shell.currentState!.resolveState()!;
    expect(state.from.titleContentKey, 'List');
    expect(state.to.titleContentKey, 'Editor');
    expect(state.progress, closeTo(flow.animation!.value, .0001));
    expect(state.settled, isFalse);
    await tester.pumpAndSettle();
    expect(shell.currentState!.resolveState()!.to.titleContentKey, 'List');
    expect(tester.takeException(), isNull);
  });

  testWidgets('mixed transitions use adjacent headers through push and pop',
      (tester) async {
    final shell = GlobalKey<GlassNavigationShellState>();
    final outer = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: outer,
      navigatorObservers: [GlassNavigationObserver()],
      theme: ThemeData(platform: TargetPlatform.iOS),
      builder: (_, child) => GlassNavigationShell(key: shell, child: child!),
      home: _nested(GlobalKey<NavigatorState>(), const _Header('Kit')),
    ));
    await tester.pumpAndSettle();
    outer.currentState!.push(PageRouteBuilder<void>(
      opaque: false,
      pageBuilder: (_, __, ___) => const _Header('Overview'),
    ));
    await tester.pumpAndSettle();
    final calendar = _route(const _Header('Calendar'));
    outer.currentState!.push(calendar);
    for (final returning in [false, true]) {
      if (returning) outer.currentState!.pop();
      await tester.pump();
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 32));
        final state = shell.currentState!.resolveState()!;
        expect(state.from.titleContentKey, 'Overview');
        expect(state.to.titleContentKey, 'Calendar');
        expect(state.progress, closeTo(calendar.animation!.value, .001));
      }
      await tester.pumpAndSettle();
    }
    expect(shell.currentState!.resolveState()!.to.titleContentKey, 'Overview');
  });

  testWidgets('ancestor back gesture cancellation retraces leaf titles',
      (tester) async {
    final shell = GlobalKey<GlassNavigationShellState>();
    final outer = GlobalKey<NavigatorState>();
    final inner = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_app(shell, outer, const _Header('List')));
    await tester.pumpAndSettle();
    final flow = _route(_nested(inner, const _Header('Create')));
    outer.currentState!.push(flow);
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(const Offset(2, 300));
    await gesture.moveBy(const Offset(220, 0));
    await tester.pump();
    final progress = shell.currentState!.resolveState()!.progress;
    expect(progress, lessThan(1));
    expect(progress, closeTo(flow.animation!.value, .0001));
    expect(shell.currentState!.resolveState()!.from.titleContentKey, 'List');
    expect(shell.currentState!.resolveState()!.to.titleContentKey, 'Create');
    await gesture.moveBy(const Offset(-180, 0));
    await tester.pump();
    expect(shell.currentState!.resolveState()!.progress, greaterThan(progress));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(shell.currentState!.resolveState()!.settled, isTrue);
    expect(shell.currentState!.resolveState()!.to.titleContentKey, 'Create');
    expect(tester.takeException(), isNull);
  });

  testWidgets('cached inactive branches never take header ownership',
      (tester) async {
    final shell = GlobalKey<GlassNavigationShellState>();
    final outer = GlobalKey<NavigatorState>();
    final branches = [GlobalKey<NavigatorState>(), GlobalKey<NavigatorState>()];
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await tester.pumpWidget(_app(
      shell,
      outer,
      ValueListenableBuilder<int>(
        valueListenable: selected,
        builder: (_, index, child) => Stack(children: [
          for (var i = 0; i < 2; i++)
            Offstage(
              offstage: i != index,
              child: GlassNavigationBranch(
                active: i == index,
                child: _nested(branches[i], _Header('Tab $i')),
              ),
            ),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
    expect(shell.currentState!.resolveState()!.to.titleContentKey, 'Tab 0');
    branches[1].currentState!.push(_route(const _Header('Hidden detail')));
    await tester.pumpAndSettle();
    expect(shell.currentState!.resolveState()!.to.titleContentKey, 'Tab 0');
    selected.value = 1;
    await tester.pumpAndSettle();
    expect(shell.currentState!.resolveState()!.to.titleContentKey,
        'Hidden detail');
    expect(shell.currentState!.resolveState()!.settled, isTrue);
    selected.value = 0;
    await tester.pumpAndSettle();
    expect(shell.currentState!.resolveState()!.to.titleContentKey, 'Tab 0');

    // A root push must blend against the selected branch, not a cached tab.
    final detail = _route(const _Header('Root detail'));
    outer.currentState!.push(detail);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final state = shell.currentState!.resolveState()!;
    expect(state.from.titleContentKey, 'Tab 0');
    expect(state.to.titleContentKey, 'Root detail');
    expect(state.progress, closeTo(detail.animation!.value, .0001));
    await tester.pumpAndSettle();
    outer.currentState!.pop();
    await tester.pumpAndSettle();
    expect(shell.currentState!.resolveState()!.to.titleContentKey, 'Tab 0');
    expect(find.byType(GlassNavigationShell), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final useRootNavigator in [false, true]) {
    testWidgets(
        'sheet shell isolates routes through exit, root=$useRootNavigator',
        (tester) async {
      final shell = GlobalKey<GlassNavigationShellState>();
      final outer = GlobalKey<NavigatorState>();
      final inner = GlobalKey<NavigatorState>();
      final sheetShell = GlobalKey<GlassNavigationShellState>();
      final sheetNavigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(
        shell,
        outer,
        _nested(inner, const _Header('App leaf')),
      ));
      await tester.pumpAndSettle();
      showModalBottomSheet<void>(
        context: tester.element(find.byType(_Header)),
        useRootNavigator: useRootNavigator,
        builder: (_) => GlassNavigationShell(
          key: sheetShell,
          child: _nested(sheetNavigator, const _Header('Sheet')),
        ),
      );
      await tester.pumpAndSettle();
      expect(shell.currentState!.resolveState(), isNull);
      expect(_pinnedTitle('App leaf'), findsNothing);
      expect(_pinnedTitle('Sheet'), findsOneWidget);
      expect(
          sheetShell.currentState!.resolveState()!.to.titleContentKey, 'Sheet');
      expect(sheetShell.currentState!.resolveState()!.settled, isTrue);
      sheetNavigator.currentState!.push(_route(const _Header('Sheet detail')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(sheetShell.currentState!.resolveState()!.from.titleContentKey,
          'Sheet');
      expect(sheetShell.currentState!.resolveState()!.to.titleContentKey,
          'Sheet detail');
      expect(shell.currentState!.resolveState(), isNull);
      await tester.pumpAndSettle();
      (useRootNavigator ? outer : inner).currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(_pinnedTitle('App leaf'), findsNothing);
      expect(sheetShell.currentState, isNotNull);
      await tester.pumpAndSettle();
      expect(
          shell.currentState!.resolveState()!.to.titleContentKey, 'App leaf');
      expect(_pinnedTitle('App leaf'), findsOneWidget);
      expect(shell.currentState!.resolveState()!.settled, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  for (final useRootNavigator in [false, true]) {
    testWidgets(
        'nested header hands back through stacked dialogs, root=$useRootNavigator',
        (tester) async {
      final shell = GlobalKey<GlassNavigationShellState>();
      final outer = GlobalKey<NavigatorState>();
      final inner = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(
        shell,
        outer,
        _nested(inner, const _Header('Leaf')),
      ));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(_Header));
      final navigator = useRootNavigator ? outer : inner;
      expect(_pinnedTitle('Leaf'), findsOneWidget);

      for (var i = 0; i < 2; i++) {
        showDialog<void>(
          context: context,
          useRootNavigator: useRootNavigator,
          builder: (_) => AlertDialog(title: Text('Dialog $i')),
        );
        await tester.pumpAndSettle();
        // Inspect the rendered overlay: resolveState alone can be correct
        // while a stale host is still painted above the modal barrier.
        expect(_pinnedTitle('Leaf'), findsNothing);
        expect(find.text('Leaf'), findsOneWidget);
      }
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(_pinnedTitle('Leaf'), findsNothing);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(_pinnedTitle('Leaf'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Finder _pinnedTitle(String title) => find.descendant(
      of: find.byType(GlassNavPinnedHost),
      matching: find.text(title),
    );

Widget _app(GlobalKey<GlassNavigationShellState> shell,
        GlobalKey<NavigatorState> navigator, Widget home) =>
    MaterialApp(
      navigatorKey: navigator,
      theme: ThemeData(platform: TargetPlatform.iOS),
      builder: (_, child) => GlassNavigationShell(key: shell, child: child!),
      home: home,
    );

CupertinoPageRoute<void> _route(Widget child) =>
    CupertinoPageRoute<void>(builder: (_) => child);

Widget _nested(GlobalKey<NavigatorState> key, Widget home) =>
    HeroControllerScope.none(
      child: Navigator(key: key, onGenerateRoute: (_) => _route(home)),
    );

class _Header extends StatelessWidget {
  const _Header(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: GlassPinnedBarChrome(
          title: Text(title),
          titleContentKey: title,
          routeDrivenTransitions: true,
          builder: (_, chrome) => Column(children: [
            if (chrome.title != null) chrome.title!,
            if (chrome.leading != null) chrome.leading!,
            ...chrome.actions,
          ]),
        ),
      );
}
