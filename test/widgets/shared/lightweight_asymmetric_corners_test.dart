import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  testWidgets('standard glass preserves sheet corners through keyboard changes',
      (tester) async {
    LightweightLiquidGlass.resetForTesting();
    addTearDown(LightweightLiquidGlass.resetForTesting);
    await tester.runAsync(LightweightLiquidGlass.preWarm);
    final boundaryKey = GlobalKey();

    for (final bottomRadius in [56.0, 0.0, 56.0]) {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: boundaryKey,
            child: LightweightLiquidGlass(
              shape: LiquidVerticalRoundedRectangle(
                topRadius: 28,
                bottomRadius: bottomRadius,
              ),
              settings: const LiquidGlassSettings(
                glassColor: Color(0xFFFFFFFF),
                bodyMode: GlassBodyMode.clear,
                blur: 0,
                thickness: 0,
                lightIntensity: 0,
                ambientStrength: 0,
                fresnelStrength: 0,
              ),
              child: const SizedBox(width: 240, height: 240),
            ),
          ),
        ),
      ));
      await tester.pump();
      // A fallback clip can look correct while the actual shader is wrong.
      expect(
        tester.allRenderObjects.any(
          (object) =>
              object.runtimeType.toString() == '_RenderLightweightGlass',
        ),
        isTrue,
      );
      final boundary = boundaryKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final pixels = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        return data!;
      });
      int alpha(int x, int y) => pixels!.getUint8((y * 240 + x) * 4 + 3);

      // These pixels are inside radius 28 but outside radius 56. Both upper
      // corners must stay filled when the inset bottom radius is larger.
      expect(alpha(10, 10), greaterThan(200),
          reason: 'top left, $bottomRadius');
      expect(alpha(229, 10), greaterThan(200),
          reason: 'top right, $bottomRadius');
      expect(alpha(0, 0), lessThan(20));
      for (final x in [10, 229]) {
        expect(
            alpha(x, 229), bottomRadius == 0 ? greaterThan(200) : lessThan(20));
      }
      expect(tester.takeException(), isNull);
    }
  });
}
