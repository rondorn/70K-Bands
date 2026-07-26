import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/services/report_html_windows_sanitize.dart';

void main() {
  test('stripWindowsUnrenderedEmoji removes flag emoji prefix', () {
    const html = '<td>🇺🇸 United States</td><td>🇩🇪 Germany</td>';
    expect(
      stripWindowsUnrenderedEmoji(html),
      '<td>United States</td><td>Germany</td>',
    );
  });

  test('stripWindowsUnrenderedEmoji removes platform emoji labels', () {
    const html = '<td>🍎 iOS</td><td>🤖 Android</td>';
    expect(stripWindowsUnrenderedEmoji(html), '<td>iOS</td><td>Android</td>');
  });

  test('stripWindowsUnrenderedEmoji removes tab icon emoji', () {
    const html =
        '<button>🎵 Band Rankings</button><button>📱 Platforms</button>';
    expect(
      stripWindowsUnrenderedEmoji(html),
      '<button>Band Rankings</button><button>Platforms</button>',
    );
  });

  test('stripWindowsUnrenderedEmoji removes gear emoji in tab labels', () {
    const html = '<button>⚙️ OS Version</button>';
    expect(stripWindowsUnrenderedEmoji(html), '<button>OS Version</button>');
  });

  test('stripWindowsUnrenderedEmoji removes globe emoji for International', () {
    const html = '<td>🌍 International</td>';
    expect(stripWindowsUnrenderedEmoji(html), '<td>International</td>');
  });

  test('stripWindowsUnrenderedEmoji leaves plain text unchanged', () {
    const html = '<td>United States</td><td>50.0%</td>';
    expect(stripWindowsUnrenderedEmoji(html), html);
  });
}
