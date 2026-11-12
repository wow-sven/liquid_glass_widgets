import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:liquid_glass_widgets/widgets/surfaces/shared/glass_nav_pinned_host.dart';

void main() {
  for (final leading in [true, false]) {
    for (final entering in [true, false]) {
      testWidgets(
          'composite handoff retraces without overlap: leading=$leading entering=$entering',
          (tester) async {
        final frame = _Frame(leading: leading, entering: entering);
        final samples = <double, (double, double, double)>{};
        Element? surface;
        for (final p in [
          0.0,
          .05,
          .1,
          .2,
          .3,
          .5,
          .8,
          1.0,
          .8,
          .5,
          .3,
          .2,
          .1,
          .05,
          0.0
        ]) {
          await frame.show(tester, p);
          final compound = _presence(tester, 'composite');
          final compact = _presence(tester, 'compact');
          expect(compound * compact, 0,
              reason:
                  'Selection fill and destination icon must never overlap.');
          final width = tester.getSize(find.byType(GlassButton)).width;
          if (width <= 122) {
            expect(compound, 0,
                reason:
                    'The wide foreground is gone before it becomes a clipped remnant.');
          }
          final old = samples[p];
          if (old != null) {
            expect(width, closeTo(old.$1, .001));
            expect(compound, old.$2);
            expect(compact, old.$3);
          } else {
            samples[p] = (width, compound, compact);
          }
          surface ??= tester.element(find.byType(GlassButton));
          expect(tester.element(find.byType(GlassButton)), same(surface));
        }
        expect(samples[0]!.$2, entering ? 0 : 1);
        expect(samples[1]!.$2, entering ? 1 : 0);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('gel foregrounds stay mounted before the legacy fade window',
      (tester) async {
    final frame = _Frame(gel: true);
    await frame.show(tester, .2);
    expect(find.byKey(const ValueKey('compact')), findsOneWidget);
    expect(_presence(tester, 'composite') * _presence(tester, 'compact'), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'compact custom foregrounds and text builders retain their existing dissolve',
      (tester) async {
    for (final frame in [
      _Frame(extent: 44),
      _Frame(text: true),
      _Frame(reduced: true)
    ]) {
      await frame.show(tester, .3);
      expect(_presence(tester, 'composite'), closeTo(.7, .001));
      expect(_presence(tester, 'compact'), closeTo(.3, .001));
    }
  });
}

double _presence(WidgetTester tester, String key) {
  final parent = tester.widget(find
      .ancestor(
        of: find.byKey(ValueKey(key)),
        matching: find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_ClusterChild'),
      )
      .first);
  return (parent as dynamic).opacity as double;
}

class _Frame {
  _Frame(
      {this.leading = true,
      this.entering = false,
      this.extent = 200,
      this.gel = false,
      this.text = false,
      this.reduced = false});
  final bool leading, entering, gel, text, reduced;
  final double extent;
  final route = MaterialPageRoute<void>(builder: (_) => const SizedBox());

  GlassNavBarRegistration registration(bool composite) {
    final item = composite
        ? GlassBarItem.custom(
            id: 'control',
            contentKey: 'composite',
            extent: extent,
            transitionBuilder:
                text ? (context, child, progress, incoming) => child : null,
            child: const Row(key: ValueKey('composite'), children: [
              Expanded(
                  child:
                      ColoredBox(color: Colors.grey, child: Text('Selected'))),
              Expanded(child: Text('Other')),
            ]),
          )
        : GlassBarItem.custom(
            id: 'control',
            contentKey: 'compact',
            extent: 44,
            child: const Icon(Icons.arrow_back, key: ValueKey('compact')),
          );
    return GlassNavBarRegistration(
      leading: leading ? [item] : const [],
      actions: leading ? const [] : [item],
      showsBackButton: false,
      buttonSize: 44,
      itemMatching: GlassBarItemMatching.position,
      contentTransition: gel
          ? GlassBarContentTransition.gel
          : GlassBarContentTransition.crossFade,
      routeDrivenTransitions: true,
    );
  }

  Future<void> show(WidgetTester tester, double progress) =>
      tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Stack(children: [
            GlassNavPinnedHost(
                state: GlassNavPinnedState(
              from: registration(!entering),
              to: registration(entering),
              progress: progress,
              coverage: 0,
              settled: false,
              topRoute: route,
            ))
          ]),
        ),
      ));
}
