import 'dart:convert';
import 'dart:typed_data';

import 'package:promoter_admin/src/services/schedule_export/event_type_labeling.dart';
import 'package:promoter_admin/src/services/schedule_export/running_order_layout.dart';

class HtmlExporter {
  const HtmlExporter._();

  static Uint8List build({
    required RunningOrderLayout layout,
    required String festivalName,
    Uint8List? logoBytes,
    String logoMimeType = 'image/png',
    bool useColor = true,
    EventTypeLabeling labeling = EventTypeLabeling.mixed,
  }) {
    final html = StringBuffer()
      ..writeln('<!doctype html>')
      ..writeln('<html lang="en"><head>')
      ..writeln('<meta charset="utf-8">')
      ..writeln('<meta name="viewport" content="width=device-width">')
      ..writeln('<title>${_escape(festivalName)} Running Order</title>')
      ..writeln('<style>${_styles()}</style>')
      ..writeln('</head><body class="${useColor ? 'color' : 'monochrome'}">');

    for (var pageIndex = 0; pageIndex < layout.pages.length; pageIndex++) {
      final page = layout.pages[pageIndex];
      final venueTemplate = 'repeat(${page.venues.length}, minmax(0, 1fr))';
      final scheduleHeightPx = _scheduleHeightPx(page);
      html
        ..writeln('<section class="running-order">')
        ..writeln('<header class="title-row">')
        ..writeln('<div class="brand">');
      if (logoBytes == null) {
        html.writeln('<strong>${_escape(festivalName)}</strong>');
      } else {
        html.writeln(
          '<img alt="${_escape(festivalName)}" '
          'src="data:$logoMimeType;base64,${base64Encode(logoBytes)}">',
        );
      }
      html
        ..writeln('</div>')
        ..writeln('<div class="day-title">');
      if (labeling.pageHeaderLabel != null) {
        html.writeln(
          '<p class="type-label">${_escape(labeling.pageHeaderLabel!)}</p>',
        );
      }
      html
        ..writeln('<h1>${_escape(page.day)}</h1>')
        ..writeln('<p>${_escape(page.displayDate)}</p></div>')
        ..writeln('<div class="running-label">RUNNING ORDER</div>')
        ..writeln('</header>')
        ..writeln(
          '<div class="venue-row" style="grid-template-columns:$venueTemplate">',
        );
      for (var i = 0; i < page.venues.length; i++) {
        final venue = page.venues[i];
        html
          ..writeln('<div class="venue venue-${i % 8}">')
          ..writeln('<strong>${_escape(venue.name)}</strong>');
        if (venue.subtitle.isNotEmpty) {
          html.writeln('<span>${_escape(venue.subtitle)}</span>');
        }
        html.writeln('</div>');
      }
      html
        ..writeln('</div>')
        ..writeln(
          '<div class="timeline" style="height:${scheduleHeightPx}px;'
          'min-height:${scheduleHeightPx}px">',
        )
        ..writeln('<div class="time-gutter left">');
      _writeHours(html, page);
      html
        ..writeln('</div>')
        ..writeln(
          '<div class="schedule" style="grid-template-columns:$venueTemplate;'
          'height:${scheduleHeightPx}px;min-height:${scheduleHeightPx}px">',
        );

      for (var venueIndex = 0; venueIndex < page.venues.length; venueIndex++) {
        html.writeln(
          '<div class="lane" style="grid-column:${venueIndex + 1}"></div>',
        );
      }
      for (
        var minute = page.startMinute;
        minute <= page.endMinute;
        minute += 60
      ) {
        final top = _percent(minute - page.startMinute, page.durationMinutes);
        html.writeln('<div class="hour-line" style="top:$top%"></div>');
      }
      for (final event in page.events) {
        final top = _percent(
          event.startMinute - page.startMinute,
          page.durationMinutes,
        );
        final height = _percent(event.durationMinutes, page.durationMinutes);
        final typeLabel = labeling.eventLabel(event.source.type);
        final laneCount = event.laneCount < 1 ? 1 : event.laneCount;
        final dense = event.sources.length > 1 || event.noteLines.isNotEmpty;
        final timeHtml = _escape(
          event.timeLine(formatClock: _clock),
        ).replaceAll('\n', '<br>');
        // Slot-locked height keeps the neat look; dense multi-band blocks may
        // still grow slightly so names are never clipped.
        final heightStyle = dense
            ? 'min-height:max(18px,calc($height% - 1px));height:auto'
            : 'height:max(18px,calc($height% - 1px));min-height:max(18px,calc($height% - 1px))';
        html.writeln(
          '<article class="event venue-${event.venueIndex % 8}'
          '${dense ? ' dense' : ''}" '
          'style="left:calc(${_percent(event.venueIndex, page.venues.length)}% + 2px + '
          '((100% / ${page.venues.length} - 4px) * ${event.laneIndex} / $laneCount));'
          'width:calc((100% / ${page.venues.length} - 4px) / $laneCount - 1px);'
          'top:$top%;$heightStyle">',
        );
        final bands = event.displayTitles;
        for (var i = 0; i < bands.length; i++) {
          final label = i < bands.length - 1 ? '${bands[i]} /' : bands[i];
          html.writeln('<strong>${_escape(label)}</strong>');
        }
        if (typeLabel != null) {
          html.writeln('<em class="event-type">${_escape(typeLabel)}</em>');
        }
        html.writeln('<time>$timeHtml</time>');
        for (final note in event.noteLines) {
          if (event.bandNames.isEmpty && event.displayTitles.contains(note)) {
            continue;
          }
          html.writeln('<small>${_escape(note)}</small>');
        }
        html.writeln('</article>');
      }
      html
        ..writeln('</div>')
        ..writeln('<div class="time-gutter right">');
      _writeHours(html, page);
      html
        ..writeln('</div></div>')
        ..writeln('<footer>${pageIndex + 1} of ${layout.pages.length}</footer>')
        ..writeln('</section>');
    }
    html.writeln('</body></html>');
    return Uint8List.fromList(utf8.encode(html.toString()));
  }

  static void _writeHours(StringBuffer html, RunningOrderPage page) {
    for (
      var minute = page.startMinute;
      minute <= page.endMinute;
      minute += 60
    ) {
      final top = _percent(minute - page.startMinute, page.durationMinutes);
      html.writeln('<span style="top:$top%">${_hourLabel(minute)}</span>');
    }
  }

  static String _styles() => '''
:root {
  color-scheme: dark;
  font-family: "Arial Narrow", "Helvetica Neue", sans-serif;
  background: #080808;
  color: white;
}
* { box-sizing: border-box; }
body { margin: 0; background: #080808; }
.running-order {
  width: 100vw;
  min-height: 100vh;
  height: auto;
  padding: 18px;
  display: flex;
  flex-direction: column;
  break-after: page;
  page-break-after: always;
  background: #080808;
}
.running-order:last-child { break-after: auto; page-break-after: auto; }
.title-row {
  height: 70px;
  flex: 0 0 auto;
  display: grid;
  grid-template-columns: 25% 50% 25%;
  align-items: center;
}
.brand { height: 54px; display: flex; align-items: center; }
.brand img { max-width: 100%; max-height: 54px; object-fit: contain; object-position: left; }
.brand strong { letter-spacing: .08em; }
.day-title { text-align: center; text-transform: uppercase; }
.day-title h1 { margin: 0; font-size: 28px; line-height: 1; }
.day-title p { margin: 5px 0 0; color: #b5b5b5; font-size: 13px; font-weight: 700; }
.day-title .type-label { margin: 0 0 4px; color: #d0d0d0; font-size: 12px; letter-spacing: .08em; }
.running-label { text-align: right; color: #b5b5b5; font-size: 12px; font-weight: 700; }
.venue-row { display: grid; margin: 0 46px; height: 54px; flex: 0 0 auto; }
.venue {
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  padding: 5px;
  text-align: center;
  text-transform: uppercase;
  border-right: 1px solid rgba(255,255,255,.25);
}
.venue strong { font-size: clamp(9px, 1.25vw, 15px); }
.venue span { margin-top: 2px; font-size: 9px; }
.timeline {
  display: grid;
  grid-template-columns: 46px 1fr 46px;
  flex: 0 0 auto;
}
.time-gutter { position: relative; color: #b5b5b5; font-size: 10px; }
.time-gutter span { position: absolute; transform: translateY(-50%); }
.time-gutter.left span { right: 8px; }
.time-gutter.right span { left: 8px; }
.schedule { position: relative; display: grid; }
.lane { grid-row: 1; border-left: 1px solid #383838; }
.lane:last-of-type { border-right: 1px solid #383838; }
.hour-line { position: absolute; left: 0; right: 0; height: 1px; background: #383838; }
.event {
  position: absolute;
  z-index: 1;
  overflow: hidden;
  padding: 5px;
  display: flex;
  flex-direction: column;
  gap: 2px;
  color: white;
  border: 1px solid rgba(255,255,255,.28);
}
.event.dense { overflow: visible; }
.event strong { font-size: clamp(8px, .95vw, 13px); line-height: 1.05; text-transform: uppercase; }
.event time { font-size: clamp(7px, .72vw, 10px); white-space: normal; }
.event .event-type {
  font-style: normal;
  font-size: clamp(7px, .7vw, 9px);
  font-weight: 700;
  letter-spacing: .04em;
  text-transform: uppercase;
}
.event small { font-size: 8px; line-height: 1.05; }
.event.dense strong { font-size: clamp(7px, .8vw, 11px); }
.event.dense time,
.event.dense .event-type,
.event.dense small { font-size: clamp(6px, .65vw, 9px); }
.venue-0 { background: #2049b5; }
.venue-1 { background: #087757; }
.venue-2 { background: #a64a08; }
.venue-3 { background: #9a20b5; }
.venue-4 { background: #37465a; }
.venue-5 { background: #df4c08; }
.venue-6 { background: #8b2030; }
.venue-7 { background: #176d87; }
.monochrome { color-scheme: light; background: #ffffff; color: #000000; }
.monochrome .running-order { background: #ffffff; }
.monochrome .brand img { filter: grayscale(1); }
.monochrome .brand strong,
.monochrome .day-title h1,
.monochrome .day-title .type-label,
.monochrome .event strong,
.monochrome .event time,
.monochrome .event .event-type,
.monochrome .event small { color: #000000; }
.monochrome .day-title p,
.monochrome .running-label,
.monochrome .time-gutter,
.monochrome footer { color: #444444; }
.monochrome .venue {
  background: #ffffff;
  color: #000000;
  border: 1px solid #000000;
}
.monochrome .lane { border-left-color: #bbbbbb; }
.monochrome .lane:last-of-type { border-right-color: #bbbbbb; }
.monochrome .hour-line { background: #bbbbbb; }
.monochrome .event { background: #ffffff; color: #000000; border-color: #000000; }
footer { height: 12px; text-align: center; color: #888; font-size: 9px; flex: 0 0 auto; }
@page { size: A4 landscape; margin: 0; }
@media print {
  html, body { width: 297mm; print-color-adjust: exact; -webkit-print-color-adjust: exact; }
  .running-order { width: 297mm; min-height: 210mm; height: auto; }
}
''';

  /// Base grid height when a day is uncrowded (same visual density as before).
  /// Longer / denser days grow past this so short slots can still hold names.
  static const double _baseScheduleHeightPx = 500;

  /// Target height for a typical 45-minute slot when the page is crowded.
  static const double _comfortableSlotPx = 48;

  static int _scheduleHeightPx(RunningOrderPage page) {
    final duration = page.durationMinutes;
    if (duration <= 0) return _baseScheduleHeightPx.round();

    var pxPerMinute = _comfortableSlotPx / 45.0;
    final venueCount = page.venues.length;
    if (venueCount > 5) {
      pxPerMinute *= 1.28;
    } else if (venueCount > 4) {
      pxPerMinute *= 1.14;
    }

    final denseCount = page.events
        .where((event) => event.sources.length > 1 || event.noteLines.isNotEmpty)
        .length;
    if (denseCount > 0) pxPerMinute *= 1.12;
    if (denseCount > 4) pxPerMinute *= 1.08;

    final shortSlots = page.events
        .where((event) => event.durationMinutes <= 45)
        .length;
    if (shortSlots > 10) pxPerMinute *= 1.08;

    final computed = duration * pxPerMinute;
    if (computed <= _baseScheduleHeightPx) {
      return _baseScheduleHeightPx.round();
    }
    return computed.round();
  }

  static String _escape(String value) => const HtmlEscape().convert(value);

  static String _clock(String value) => value.trim().replaceAll(':', '.');

  static String _hourLabel(int timelineMinute) {
    final hour = (timelineMinute ~/ 60) % 24;
    return '${hour.toString().padLeft(2, '0')}:00';
  }

  static String _percent(num value, num total) =>
      (value * 100 / total).toStringAsFixed(5);
}
