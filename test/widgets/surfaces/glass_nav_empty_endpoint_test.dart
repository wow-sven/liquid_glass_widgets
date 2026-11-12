import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:liquid_glass_widgets/widgets/effects/shared/glass_materialize_effect.dart';
import 'package:liquid_glass_widgets/widgets/surfaces/shared/glass_nav_pinned_host.dart';

void main() {
  for (final leading in [true, false]) {
    for (final direction in TextDirection.values) {
      testWidgets(
          'empty endpoint contracts and retraces, leading=$leading $direction',
          (tester) async {
        final frame = _Frame(leading: leading, direction: direction);
        await frame.show(tester, 0);
        final full = frame.rect(tester);
        expect(full.width, 200);
        final edge = frame.anchor(full);
        final widths = <double>[];
        for (final progress in [0.0, .12, .28, .42, .54]) {
          await frame.show(tester, progress);
          final rect = frame.rect(tester);
          widths.add(rect.width);
          expect(frame.anchor(rect), closeTo(edge, .001));
          expect(rect.height, 44);
          expect(tester.getSize(find.byKey(const ValueKey('foreground'))).width,
              200,
              reason:
                  'The foreground is clipped, never horizontally squeezed.');
        }
        for (var i = 1; i < widths.length; i++) {
          expect(widths[i], lessThan(widths[i - 1]));
        }
        expect(widths.last, closeTo(44, .5));
        // Moving back through the same route progress must restore exact frames.
        await frame.show(tester, .28);
        expect(frame.rect(tester).width, closeTo(widths[2], .001));
        // An entering group has the same geometry at the mirrored progress.
        await frame.show(tester, .72, entering: true);
        expect(frame.rect(tester).width, closeTo(widths[2], .001));
        final effect = tester.widget<GlassMaterializeEffect>(
            find.byType(GlassMaterializeEffect));
        expect(effect.progress, inExclusiveRange(.45, .55));
        expect(effect.scaleFrom, 1);
        expect(effect.profile, GlassMaterializeProfile.uniform);
        final opacity = tester
            .widgetList<Opacity>(find.ancestor(
              of: find.byKey(const ValueKey('foreground')),
              matching: find.byType(Opacity),
            ))
            .fold(1.0, (value, widget) => value * widget.opacity);
        expect(opacity, closeTo(effect.progress, .001),
            reason: 'the whole group fades once, including on entry');
        await frame.show(tester, 1, settled: true);
        expect(find.byType(GlassButton), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('empty endpoint follows button size and reserves no title space',
      (tester) async {
    final frame = _Frame(leading: true, buttonSize: 52);
    await frame.show(tester, .54);
    expect(frame.rect(tester).width, closeTo(52, .5));
    expect(frame.rect(tester).height, 52);
    final title = tester.getTopLeft(find.text('Destination'));
    await frame.show(tester, 1, settled: true);
    expect(tester.getTopLeft(find.text('Destination')), title);
    expect(tester.takeException(), isNull);
  });

  testWidgets('contraction is substantial before the glass fades away',
      (tester) async {
    final frame = _Frame(leading: true);
    // About 31 ms into the shared 260 ms tab clock.
    await frame.show(tester, .12);
    expect(frame.rect(tester).width, lessThan(150));
    final effect = tester
        .widget<GlassMaterializeEffect>(find.byType(GlassMaterializeEffect));
    expect(effect.progress, greaterThan(.7));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion retains full geometry before switching away',
      (tester) async {
    final frame = _Frame(leading: true, reduced: true);
    await frame.show(tester, .25);
    expect(frame.rect(tester).width, 200);
    await frame.show(tester, 1, settled: true);
    expect(find.byType(GlassButton), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _Frame {
  _Frame(
      {required this.leading,
      this.direction = TextDirection.ltr,
      this.buttonSize = 44,
      this.reduced = false});
  final bool leading, reduced;
  final TextDirection direction;
  final double buttonSize;
  final route = MaterialPageRoute<void>(builder: (_) => const SizedBox());

  GlassNavBarRegistration registration(bool populated) {
    final items = <GlassBarItem>[
      if (populated)
        GlassBarItem.custom(
          id: 'wide',
          child: const SizedBox(
              key: ValueKey('foreground'),
              width: 200,
              child: Text('A wide action group')),
        ),
    ];
    return GlassNavBarRegistration(
      leading: leading ? items : const [],
      actions: leading ? const [] : items,
      showsBackButton: false,
      buttonSize: buttonSize,
      title: Text(populated ? 'Source' : 'Destination'),
      titleContentKey: populated,
      routeDrivenTransitions: true,
    );
  }

  Future<void> show(WidgetTester tester, double progress,
      {bool entering = false, bool settled = false}) async {
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: GlassAccessibilityScope(
            reduceMotion: reduced,
            child: Stack(children: [
              GlassNavPinnedHost(
                  state: GlassNavPinnedState(
                from: registration(!entering),
                to: registration(entering),
                progress: progress,
                coverage: 0,
                settled: settled,
                topRoute: route,
              )),
            ]),
          ),
        ),
      ),
    ));
  }

  Rect rect(WidgetTester tester) => tester.getRect(find.byType(GlassButton));
  double anchor(Rect rect) =>
      leading == (direction == TextDirection.ltr) ? rect.left : rect.right;
}
