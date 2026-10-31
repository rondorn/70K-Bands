import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/widgets/ios_keyboard_dismiss.dart';

void main() {
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

  testWidgets('iOS Done bar dismisses a focused description field', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    _showKeyboard(tester, bottom: 300);

    await tester.pumpWidget(
      _harness(
        TextField(
          focusNode: focus,
          maxLines: 8,
          minLines: 4,
          decoration: const InputDecoration(hintText: 'Band description text…'),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(focus.hasFocus, isTrue);
    expect(find.text('Done'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is MediaQuery &&
            widget.data.viewInsets.bottom == 300 + IosKeyboardDismiss.barHeight,
      ),
      findsAtLeastNWidgets(1),
    );

    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final done = tester.getRect(find.text('Done'));
    expect(done.bottom, lessThanOrEqualTo(screenHeight - 300));
    expect(
      done.top,
      greaterThanOrEqualTo(screenHeight - 300 - IosKeyboardDismiss.barHeight),
    );

    await tester.tap(find.text('Done'));
    await tester.pump();

    expect(focus.hasFocus, isFalse);
  }, variant: ios);

  testWidgets('iOS tap outside the field dismisses the keyboard', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);

    await tester.pumpWidget(
      _harness(
        Column(
          children: [
            TextField(focusNode: focus, maxLines: 6),
            const SizedBox(height: 24),
            const Text('Outside the description'),
          ],
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focus.hasFocus, isTrue);

    await tester.tap(find.text('Outside the description'));
    await tester.pump();

    expect(focus.hasFocus, isFalse);
  }, variant: ios);

  testWidgets('Done bar stays hidden until the iOS keyboard is open', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const TextField(maxLines: 4)));
    expect(find.text('Done'), findsNothing);
  }, variant: ios);

  testWidgets('non-iOS keyboards do not get a Done bar', (tester) async {
    _showKeyboard(tester, bottom: 300);
    await tester.pumpWidget(_harness(const TextField(maxLines: 8)));
    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(find.text('Done'), findsNothing);
  });
}

void _showKeyboard(WidgetTester tester, {required double bottom}) {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: bottom);
  tester.view.padding = FakeViewPadding.zero;
  tester.view.viewPadding = FakeViewPadding.zero;
  addTearDown(tester.view.reset);
}

Widget _harness(Widget body) {
  return MaterialApp(
    builder: (context, child) {
      return IosKeyboardDismiss(child: child ?? const SizedBox.shrink());
    },
    home: Scaffold(body: body),
  );
}
