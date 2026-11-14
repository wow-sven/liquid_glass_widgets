import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:liquid_glass_widgets/widgets/surfaces/shared/glass_nav_pinned_host.dart';

GlassBarActionItem textAction(String id, String label) => GlassBarCustomItem(
      id: id,
      contentKey: ('text', label),
      onTap: () {},
      child: Center(
          widthFactor: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(label),
          )),
    );

GlassNavBarRegistration registration(List<GlassBarItem> actions,
        {String? title}) =>
    GlassNavBarRegistration(
      actions: actions,
      showsBackButton: false,
      title: title == null ? null : Text(title),
      titleContentKey: title,
      itemMatching: GlassBarItemMatching.position,
      contentTransition: GlassBarContentTransition.crossFade,
      routeDrivenTransitions: true,
    );

void main() {
  test(
      'business identity remains available while presentation matches from the edge',
      () {
    final a = textAction('save', 'Done');
    final b = textAction('finish', 'Done');
    expect(matchGlassNavActions([a], [b]), hasLength(2));
    final matched =
        matchGlassNavActions([a], [b], matchByPosition: true).single;
    expect(matched.fromItem, same(a));
    expect(matched.toItem, same(b));
    expect(matched.crossFades, isFalse);
    final extra = textAction('extra', 'Extra');
    final slots = matchGlassNavActions([extra, a], [b], matchByPosition: true);
    expect(slots.first.fromItem, same(a));
    expect(slots.last.isExit, isTrue);
    final reversed =
        matchGlassNavActions([b], [extra, a], matchByPosition: true);
    expect(reversed.last.fromItem, same(b));
    expect(reversed.first.isEnter, isTrue);
  });

  testWidgets(
      'content swaps retain one shell, adapt width and retrace every sampled frame',
      (tester) async {
    final route = MaterialPageRoute<void>(builder: (_) => const SizedBox());
    final from = registration([textAction('save', 'Save')], title: 'Overview');
    final to =
        registration([textAction('finish', 'Finish editing')], title: 'Phase');
    Future<void> frame(double p) => tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Stack(children: [
            GlassNavPinnedHost(
                state: GlassNavPinnedState(
              from: from,
              to: to,
              progress: p,
              coverage: 0,
              settled: p == 1,
              topRoute: route,
            ))
          ])),
        ));
    final samples = <double, Rect>{};
    Element? shell;
    for (final p in [0.0, .1, .3, .5, .7, 1.0, .7, .5, .3, .1, 0.0]) {
      await frame(p);
      final cluster = find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_PinnedCluster');
      expect(cluster, findsOneWidget);
      final dynamic widget = tester.widget(cluster);
      expect(widget.morphScale, 1,
          reason: 'content replacement must not swell');
      final rect = tester.getRect(cluster);
      expect(rect.height, GlassNavPinnedMetrics.slot);
      shell ??= tester.element(cluster);
      expect(tester.element(cluster), same(shell));
      if (samples.containsKey(p)) {
        expect(rect, samples[p],
            reason: 'reversal must retrace geometry at $p');
      } else {
        samples[p] = rect;
      }
      final title = find.descendant(
          of: find.byType(GlassNavPinnedTitle), matching: find.byType(Text));
      expect(title, findsOneWidget);
      expect(tester.widget<Text>(title).data, p < .5 ? 'Overview' : 'Phase');
      expect(tester.takeException(), isNull);
    }
    expect(samples[1]!.width, greaterThan(samples[0]!.width));
  });

  testWidgets(
      'text to icon is a content swap and independent shells still fuse',
      (tester) async {
    final route = MaterialPageRoute<void>(builder: (_) => const SizedBox());
    final icon = GlassBarItem.icon(
        id: 'search', icon: const Icon(Icons.search), onTap: () {});
    Future<void> frame(List<GlassBarItem> a, List<GlassBarItem> b, double p) =>
        tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Stack(children: [
            GlassNavPinnedHost(
                state: GlassNavPinnedState(
              from: registration(a),
              to: registration(b),
              progress: p,
              coverage: 0,
              settled: false,
              topRoute: route,
            ))
          ])),
        ));
    await frame([textAction('save', 'Save')], [icon], .35);
    final clusters = find
        .byWidgetPredicate((w) => w.runtimeType.toString() == '_PinnedCluster');
    expect(clusters, findsOneWidget);
    expect((tester.widget(clusters) as dynamic).morphScale, 1);
    final left = GlassBarItem.icon(
        id: 'left',
        icon: const Icon(Icons.add),
        onTap: () {},
        background: GlassBarItemBackground.separate);
    final right = GlassBarItem.icon(
        id: 'right',
        icon: const Icon(Icons.share),
        onTap: () {},
        background: GlassBarItemBackground.separate);
    await frame([right], [left, right], .15);
    expect(clusters, findsNWidgets(2));
    final layers = tester.widgetList<AdaptiveLiquidGlassLayer>(
        find.byType(AdaptiveLiquidGlassLayer));
    expect(layers.any((layer) => layer.blendAmount > 0), isTrue);
    final rects = clusters
        .evaluate()
        .map((e) => tester.getRect(find.byWidget(e.widget)))
        .toList();
    await frame([right], [left, right], .7);
    await frame([right], [left, right], .15);
    expect(
        clusters
            .evaluate()
            .map((e) => tester.getRect(find.byWidget(e.widget)))
            .toList(),
        rects);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'route-driven title and controls follow cancelled and committed iOS swipes',
      (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(CupertinoApp(
      navigatorKey: navigator,
      builder: (_, child) => GlassNavigationShell(child: child!),
      home: const _Page(title: 'Overview'),
    ));
    await tester.pumpAndSettle();
    navigator.currentState!.push(
        CupertinoPageRoute<void>(builder: (_) => const _Page(title: 'Phase')));
    await tester.pumpAndSettle();
    GlassNavPinnedState state() => tester
        .widget<GlassNavPinnedHost>(find.byType(GlassNavPinnedHost))
        .state;
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final gesture = await tester.startGesture(const Offset(2, 300));
    await gesture.moveBy(Offset(width * .25, 0));
    await tester.pump();
    expect(state().progress, inExclusiveRange(0, 1));
    expect(state().progress, closeTo(state().topRoute.animation!.value, .001));
    expect(state().popping, isFalse,
        reason: 'keep endpoints fixed for exact reversal');
    await gesture.moveBy(Offset(-width * .2, 0));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(navigator.currentState!.canPop(), isTrue);
    expect(state().settled, isTrue);
    expect(state().to.titleContentKey, 'Phase');
    final commit = await tester.startGesture(const Offset(2, 300));
    await commit.moveBy(Offset(width * .8, 0));
    await tester.pump();
    expect(state().progress, closeTo(state().topRoute.animation!.value, .001));
    await commit.up();
    await tester.pumpAndSettle();
    expect(navigator.currentState!.canPop(), isFalse);
    expect(state().to.titleContentKey, 'Overview');
    expect(state().settled, isTrue);
    expect(tester.takeException(), isNull);
  });
}

class _Page extends StatelessWidget {
  const _Page({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
        child: SafeArea(
            child: GlassPinnedBarChrome(
          title: Text(title),
          titleContentKey: title,
          itemMatching: GlassBarItemMatching.position,
          contentTransition: GlassBarContentTransition.crossFade,
          routeDrivenTransitions: true,
          actions: [textAction(title, 'Done')],
          builder: (_, chrome) => SizedBox(
              height: 44,
              child: Row(children: [
                if (chrome.leading != null) chrome.leading!,
                Expanded(child: chrome.title ?? const SizedBox()),
                ...chrome.actions,
              ])),
        )),
      );
}
