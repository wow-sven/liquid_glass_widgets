import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:liquid_glass_widgets/widgets/surfaces/shared/glass_nav_pinned_host.dart';

void main() {
  testWidgets('local actions follow progress and retrace without remounting',
      (tester) async {
    final route = MaterialPageRoute<void>(builder: (_) => const SizedBox());
    var addTaps = 0;
    var menuTaps = 0;
    final add = GlassBarItem.icon(
        id: 'add', icon: const Icon(Icons.add), onTap: () => addTaps++);
    final menu = GlassBarItem.icon(
        id: 'menu', icon: const Icon(Icons.menu), onTap: () => menuTaps++);
    Future<void> frame(double p) => tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Stack(children: [
            GlassNavPinnedHost(
                state: GlassNavPinnedState(
              from: const GlassNavBarRegistration(
                  actions: [], showsBackButton: false),
              to: GlassNavBarRegistration(
                actions: p == 0 ? [add, menu] : [add],
                actionsTransition: GlassBarActionTransition(
                    from: [add, menu], to: [add], progress: p),
                showsBackButton: false,
                title: const Text('Chat'),
                titleContentKey: 'chat',
                itemMatching: GlassBarItemMatching.position,
                routeDrivenTransitions: true,
              ),
              progress: 1,
              coverage: 0,
              settled: true,
              topRoute: route,
            ))
          ])),
        ));
    final cluster = find
        .byWidgetPredicate((w) => w.runtimeType.toString() == '_PinnedCluster');
    final rects = <double, Rect>{};
    Element? element;
    Rect? titleRect;
    for (final p in [0.0, .1, .25, .5, .75, 1.0, .75, .5, .25, .1, 0.0]) {
      await frame(p);
      expect(cluster, findsOneWidget);
      element ??= tester.element(cluster);
      expect(tester.element(cluster), same(element));
      final rect = tester.getRect(cluster);
      if (rects.containsKey(p)) {
        expect(rect, rects[p]);
      } else {
        rects[p] = rect;
      }
      titleRect ??= tester.getRect(find.text('Chat'));
      expect(tester.getRect(find.text('Chat')).topLeft, titleRect.topLeft);
      // A surviving action keeps one visible face instead of matching the
      // trailing menu slot and cross-fading it into a second add icon.
      expect(find.byIcon(Icons.add), findsOneWidget);
      if (p == 1) {
        expect(find.byIcon(Icons.menu), findsNothing);
        await tester.tap(find.byIcon(Icons.add));
        expect(addTaps, 1);
      }
    }
    final closed = rects[0.0]!;
    final opened = rects[1.0]!;
    for (final p in [.1, .25, .5, .75]) {
      expect(rects[p]!.width,
          closeTo(closed.width + (opened.width - closed.width) * p, .001));
      expect(rects[p]!.right, closed.right);
    }
    await tester.tap(find.byIcon(Icons.menu));
    expect(menuTaps, 1, reason: 'cancelled gestures restore interaction');
    expect(tester.takeException(), isNull);
  });

  test('route, branch and coverage transitions retain priority', () {
    final route = MaterialPageRoute<void>(builder: (_) => const SizedBox());
    final from = GlassNavBarRegistration(actions: [
      GlassBarItem.icon(id: 'back', icon: const Icon(Icons.home), onTap: () {})
    ], showsBackButton: false);
    final to = GlassNavBarRegistration(
        actions: [],
        showsBackButton: false,
        actionsTransition: GlassBarActionTransition(
            from: from.actions, to: const [], progress: .4));
    for (final sample in [(false, 0.0), (true, .2)]) {
      final state = GlassNavPinnedState(
          from: from,
          to: to,
          progress: .6,
          coverage: sample.$2,
          settled: sample.$1,
          topRoute: route);
      expect(state.actionState, same(state));
    }
  });
}
