import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  for (final quality in [GlassQuality.standard, GlassQuality.premium]) {
    for (final axis in Axis.values) {
      testWidgets('$quality $axis only dragging lifts the selection pill',
          (tester) async {
        var selected = 0;
        late StateSetter update;
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(builder: (context, setState) {
                update = setState;
                return SizedBox(
                  width: axis == Axis.horizontal ? 300 : 48,
                  child: GlassSegmentedControl(
                    segments: const [
                      GlassSegment(label: 'One'),
                      GlassSegment(label: 'Two'),
                      GlassSegment(label: 'Three'),
                    ],
                    direction: axis,
                    height: 48,
                    segmentExtent: 100,
                    selectedIndex: selected,
                    onSegmentSelected: (index) =>
                        setState(() => selected = index),
                    quality: quality,
                    useOwnLayer: true,
                  ),
                );
              }),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        Iterable<AnimatedGlassIndicator> indicators() =>
            tester.widgetList<AnimatedGlassIndicator>(
                find.byType(AnimatedGlassIndicator));
        void expectResting() {
          for (final indicator in indicators()) {
            expect(indicator.thickness, 0);
            expect(indicator.velocity, 0,
                reason: 'Taps must not jelly-stretch');
          }
        }

        // A stationary press must not lift, even if held past the tap deadline.
        final press =
            await tester.startGesture(tester.getCenter(find.text('Two')));
        await tester.pump(const Duration(milliseconds: 150));
        expectResting();
        await press.up();
        await tester.pump();
        var sawMovement = false;
        for (var i = 0; i < 24; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          expectResting();
          final alignment =
              indicators().first.alignment.resolve(TextDirection.ltr);
          final position = axis == Axis.horizontal ? alignment.x : alignment.y;
          sawMovement |= position > -0.99 && position < -0.01;
        }
        expect(selected, 1);
        expect(sawMovement, isTrue, reason: 'The resting pill should slide');
        await tester.pumpAndSettle();

        final drag =
            await tester.startGesture(tester.getCenter(find.text('Two')));
        await drag.moveBy(axis == Axis.horizontal
            ? const Offset(70, 0)
            : const Offset(0, 70));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(indicators().first.thickness, greaterThan(0.1));
        await drag.up();
        await tester.pumpAndSettle();
        expectResting();

        // A value supplied by a page swipe or keyboard must stay flat too,
        // including after a drag has already occurred.
        update(() => selected = 0);
        for (var i = 0; i < 24; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          expectResting();
        }
        await tester.pumpAndSettle();
        final cancel =
            await tester.startGesture(tester.getCenter(find.text('One')));
        await cancel.moveBy(axis == Axis.horizontal
            ? const Offset(70, 0)
            : const Offset(0, 70));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(indicators().first.thickness, greaterThan(0.1));
        await cancel.cancel();
        await tester.pumpAndSettle();
        expectResting();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
