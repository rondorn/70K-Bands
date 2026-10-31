import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/widgets/layout_breakpoints.dart';

void main() {
  group('isPhoneLayoutForShortestSide', () {
    test('desktop never uses phone chrome', () {
      expect(
        isPhoneLayoutForShortestSide(
          400,
          isDesktopPlatform: true,
          isIos: false,
        ),
        isFalse,
      );
    });

    test('classic iPhone uses phone chrome', () {
      expect(
        isPhoneLayoutForShortestSide(
          390,
          isDesktopPlatform: false,
          isIos: true,
        ),
        isTrue,
      );
    });

    test('open Duo uses phone chrome on iOS', () {
      expect(
        isPhoneLayoutForShortestSide(
          650,
          isDesktopPlatform: false,
          isIos: true,
        ),
        isTrue,
        reason: 'Open Duo exceeds classic phone width but is still a phone',
      );
    });

    test('iPad mini and larger keep desktop/iPad chrome', () {
      expect(
        isPhoneLayoutForShortestSide(
          744,
          isDesktopPlatform: false,
          isIos: true,
        ),
        isFalse,
      );
      expect(
        isPhoneLayoutForShortestSide(
          1024,
          isDesktopPlatform: false,
          isIos: true,
        ),
        isFalse,
      );
    });

    test('Android keeps the classic phone threshold', () {
      expect(
        isPhoneLayoutForShortestSide(
          650,
          isDesktopPlatform: false,
          isIos: false,
        ),
        isFalse,
      );
      expect(
        isPhoneLayoutForShortestSide(
          400,
          isDesktopPlatform: false,
          isIos: false,
        ),
        isTrue,
      );
    });
  });
}
