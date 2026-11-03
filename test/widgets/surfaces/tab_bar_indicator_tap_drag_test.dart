import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  for (final searchable in [false, true]) {
    testWidgets(
        '${searchable ? "Searchable" : "Inline"} tab indicator slides on tap and lifts on drag',
        (tester) async {
      const tabs = [
        GlassTab(label: 'Home', icon: Icon(Icons.home)),
        GlassTab(label: 'Browse', icon: Icon(Icons.search)),
      ];
      var selected = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: StatefulBuilder(builder: (context, setState) {
                void select(int index) => setState(() => selected = index);
                return searchable
                    ? GlassTabBar.searchable(
                        tabs: tabs,
                        selectedIndex: selected,
                        onTabSelected: select,
                        searchConfig: GlassSearchBarConfig(
                          hintText: 'Search',
                          onSearchToggle: (_) {},
                        ),
                      )
                    : GlassTabBar.inline(
                        tabs: tabs,
                        selectedIndex: selected,
                        onTabSelected: select,
                      );
              }),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final pills = find.byType(AnimatedGlassIndicator);
      final target = tester.getCenter(find.byIcon(Icons.search).first);
      final press = await tester.startGesture(target);
      await tester.pump(const Duration(milliseconds: 150));
      var sawSlide = false;
      Future<void> checkSlide() async {
        await tester.pump(const Duration(milliseconds: 16));
        final indicators = tester.widgetList<AnimatedGlassIndicator>(pills);
        expect(indicators, isNotEmpty);
        for (final pill in indicators) {
          expect(pill.thickness, 0);
          expect(pill.velocity, 0);
          sawSlide |= pill.alignment.resolve(TextDirection.ltr).x.abs() < 0.99;
        }
      }

      await checkSlide();
      await press.up();
      for (var i = 0; i < 24; i++) {
        await checkSlide();
      }
      expect(selected, 1);
      expect(sawSlide, isTrue);
      await tester.pumpAndSettle();

      final drag = await tester.startGesture(target);
      await drag.moveBy(const Offset(-60, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.widget<AnimatedGlassIndicator>(pills.first).thickness,
          greaterThan(0.1));
      await drag.up();
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedGlassIndicator>(pills.first).thickness, 0);
    });
  }
}
