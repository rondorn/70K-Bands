import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:promoter_admin/src/widgets/url_image_preview.dart';

void main() {
  test('resolvePreviewImageUrl returns empty for blank input', () {
    expect(resolvePreviewImageUrl(''), '');
    expect(resolvePreviewImageUrl(' '), '');
    expect(resolvePreviewImageUrl('   '), '');
  });

  test('resolvePreviewImageUrl prepends https for scheme-stripped URLs', () {
    expect(
      resolvePreviewImageUrl('www.metal-archives.com/images/1/2/logo.png'),
      'https://www.metal-archives.com/images/1/2/logo.png',
    );
  });

  test('resolvePreviewImageUrl keeps existing schemes', () {
    expect(
      resolvePreviewImageUrl('http://example.com/a.png'),
      'http://example.com/a.png',
    );
    expect(
      resolvePreviewImageUrl('https://example.com/a.png'),
      'https://example.com/a.png',
    );
  });

  test('resolvePreviewImageUrl normalizes Dropbox dl=0 to raw=1', () {
    expect(
      resolvePreviewImageUrl(
        'https://www.dropbox.com/s/abc/logo.png?dl=0',
      ),
      'https://www.dropbox.com/s/abc/logo.png?raw=1',
    );
  });

  test('knockoutPureBlackPreview makes pure black transparent', () {
    final src = img.Image(width: 2, height: 1, numChannels: 4);
    src.setPixelRgba(0, 0, 0, 0, 0, 255);
    src.setPixelRgba(1, 0, 255, 255, 255, 255);
    final bytes = Uint8List.fromList(img.encodePng(src));

    final out = knockoutPureBlackPreview(bytes);
    expect(out, isNotNull);
    final decoded = img.decodeImage(out!);
    expect(decoded, isNotNull);
    expect(decoded!.getPixel(0, 0).a, 0);
    expect(decoded.getPixel(1, 0).r, 255);
    expect(decoded.getPixel(1, 0).a, 255);
  });

  test('knockoutPureBlackPreview treats 2% near-black as transparent', () {
    // 2% of 255 ≈ 5; (5,5,5) should knock out, (6,6,6) should not.
    final src = img.Image(width: 4, height: 1, numChannels: 4);
    src.setPixelRgba(0, 0, 1, 1, 1, 255);
    src.setPixelRgba(1, 0, 5, 5, 5, 255);
    src.setPixelRgba(2, 0, 6, 6, 6, 255);
    src.setPixelRgba(3, 0, 254, 0, 0, 255);
    final bytes = Uint8List.fromList(img.encodePng(src));

    final out = knockoutPureBlackPreview(bytes)!;
    final decoded = img.decodeImage(out)!;
    expect(decoded.getPixel(0, 0).a, 0);
    expect(decoded.getPixel(1, 0).a, 0);
    expect(decoded.getPixel(2, 0).a, 255);
    expect(decoded.getPixel(3, 0).r, 254);
    expect(decoded.getPixel(3, 0).a, 255);
  });

  test('knockoutPureBlackPreview returns null for garbage bytes', () {
    expect(knockoutPureBlackPreview(Uint8List.fromList([1, 2, 3])), isNull);
  });
}
