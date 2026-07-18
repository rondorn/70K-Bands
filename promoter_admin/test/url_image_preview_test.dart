import 'package:flutter_test/flutter_test.dart';
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
}
