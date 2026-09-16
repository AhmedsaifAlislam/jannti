import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jannti/widgets/jannati_logo.dart';

void main() {
  testWidgets('Render official Jannati Logo to 1024x1024 PNG', (tester) async {
    final key = GlobalKey();
    tester.view.physicalSize = const Size(1024, 1024);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF04140D),
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: const JannatiLogo(size: 820, showGlow: false),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    final outFile = File('assets/images/official_jannati_icon_1024.png');
    outFile.writeAsBytesSync(pngBytes);
    // ignore: avoid_print
    print('SUCCESS_RENDERED_ICON: ${pngBytes.length} bytes');
  });
}
