import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';

/// Lets iOS close the software keyboard after editing text.
///
/// Multiline fields (band, event, and description text) use Return for new
/// lines, so the keyboard has no Done key. Flutter also ignores a touch
/// outside the field on iOS, which leaves the keyboard on screen. This adds a
/// Done bar above the keyboard and unfocuses the field when the user taps
/// outside it.
class IosKeyboardDismiss extends StatelessWidget {
  const IosKeyboardDismiss({super.key, required this.child});

  final Widget child;

  /// Height of the bar that sits on top of the iOS keyboard.
  static const double barHeight = 44;

  static bool get enabled =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    final mediaQuery = MediaQuery.of(context);
    final keyboard = mediaQuery.viewInsets.bottom;
    final showBar = keyboard > 0;

    return Stack(
      fit: StackFit.expand,
      children: [
        MediaQuery(
          data: showBar
              ? mediaQuery.copyWith(
                  viewInsets: mediaQuery.viewInsets.copyWith(
                    bottom: keyboard + barHeight,
                  ),
                )
              : mediaQuery,
          child: Actions(
            actions: <Type, Action<Intent>>{
              EditableTextTapOutsideIntent:
                  CallbackAction<EditableTextTapOutsideIntent>(
                    onInvoke: (intent) {
                      intent.focusNode.unfocus();
                      return null;
                    },
                  ),
            },
            child: child,
          ),
        ),
        if (showBar)
          Positioned(
            left: 0,
            right: 0,
            bottom: keyboard,
            height: barHeight,
            child: _KeyboardDoneBar(
              leftInset: mediaQuery.viewPadding.left,
              rightInset: mediaQuery.viewPadding.right,
            ),
          ),
      ],
    );
  }
}

class _KeyboardDoneBar extends StatelessWidget {
  const _KeyboardDoneBar({required this.leftInset, required this.rightInset});

  final double leftInset;
  final double rightInset;

  @override
  Widget build(BuildContext context) {
    return TextFieldTapRegion(
      child: Material(
        color: AppColors.navPanel,
        child: InkWell(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.panelBorder)),
            ),
            child: Padding(
              padding: EdgeInsets.only(left: leftInset, right: rightInset + 16),
              child: const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Done',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
