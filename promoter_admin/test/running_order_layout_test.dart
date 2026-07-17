import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/schedule_export/event_type_labeling.dart';
import 'package:promoter_admin/src/services/schedule_export/html_exporter.dart';
import 'package:promoter_admin/src/services/schedule_export/pdf_exporter.dart';
import 'package:promoter_admin/src/services/schedule_export/running_order_layout.dart';
import 'package:promoter_admin/src/services/schedule_service.dart';

ScheduleEvent event({
  required String band,
  required String day,
  required String date,
  required String venue,
  required String start,
  required String end,
  String type = 'Show',
}) {
  return ScheduleEvent(
    band: band,
    day: day,
    date: date,
    location: venue,
    startTime: start,
    endTime: end,
    type: type,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const workspace = FestivalWorkspace(
    days: ['Day 1', 'Day 2'],
    dates: ['1/29/2026', '1/30/2026', '1/31/2026'],
    venues: ['Pool (Deck 11)', 'Theater'],
    dateRolloverTime: '8:00',
  );

  test('festival logo url survives local preference serialization', () {
    final restored = FestivalWorkspace.fromPrefs(
      workspace
          .copyWith(
            festivalLogoUrl: 'https://www.dropbox.com/s/abc/logo.png?dl=0',
          )
          .toPrefs(),
    );
    expect(
      restored.festivalLogoUrl,
      'https://www.dropbox.com/s/abc/logo.png?dl=0',
    );
  });

  test('migrates legacy festivalLogoPath into festivalLogoUrl', () {
    final restored = FestivalWorkspace.fromPrefs({
      'festivalLogoPath': 'https://example.com/legacy-logo.png',
    });
    expect(restored.festivalLogoUrl, 'https://example.com/legacy-logo.png');
  });

  test('groups pages and venues in configured order', () {
    final layout = RunningOrderLayout.build([
      event(
        band: 'Late',
        day: 'Day 2',
        date: '1/30/2026',
        venue: 'Theater',
        start: '19:00',
        end: '20:00',
      ),
      event(
        band: 'First',
        day: 'Day 1',
        date: '1/29/2026',
        venue: 'Pool (Deck 11)',
        start: '17:30',
        end: '18:15',
      ),
      event(
        band: 'Second',
        day: 'Day 1',
        date: '1/29/2026',
        venue: 'Theater',
        start: '18:15',
        end: '19:00',
      ),
    ], workspace);

    expect(layout.pages.map((page) => page.day), ['Day 1', 'Day 2']);
    expect(layout.pages.first.venues.map((venue) => venue.name), [
      'Pool',
      'Theater',
    ]);
    expect(layout.pages.first.venues.first.subtitle, '(Deck 11)');
    expect(layout.pages.first.date, '1/29/2026');
  });

  test('normalizes after-midnight events onto the same festival timeline', () {
    final layout = RunningOrderLayout.build([
      event(
        band: 'Night',
        day: 'Day 1',
        date: '1/30/2026',
        venue: 'Theater',
        start: '23:30',
        end: '00:30',
      ),
      event(
        band: 'Later',
        day: 'Day 1',
        date: '1/30/2026',
        venue: 'Theater',
        start: '01:15',
        end: '02:00',
      ),
    ], workspace);

    final page = layout.pages.single;
    expect(page.events.first.startMinute, 23 * 60 + 30);
    expect(page.events.first.endMinute, 24 * 60 + 30);
    expect(page.events.last.startMinute, 25 * 60 + 15);
    expect(page.endMinute, 26 * 60);
  });

  test('filters types case-insensitively and omits empty days', () {
    final events = [
      event(
        band: 'Band',
        day: 'Day 1',
        date: '1/29/2026',
        venue: 'Pool (Deck 11)',
        start: '17:30',
        end: '18:15',
      ),
      event(
        band: 'Clinic',
        day: 'Day 2',
        date: '1/30/2026',
        venue: 'Theater',
        start: '12:00',
        end: '13:00',
        type: 'Clinic',
      ),
    ];

    final filtered = RunningOrderLayout.filterByTypes(events, {'show'});
    final layout = RunningOrderLayout.build(filtered, workspace);
    expect(filtered.map((item) => item.band), ['Band']);
    expect(layout.pages.map((page) => page.day), ['Day 1']);
  });

  test('merges same-slot multi-band meet and greets and packs overlaps', () {
    final layout = RunningOrderLayout.build([
      event(
        band: 'Illdisposed',
        day: 'Day 1',
        date: '1/29/2026',
        venue: 'Boleros',
        start: '12:00',
        end: '13:00',
        type: 'Meet and Greet',
      ),
      event(
        band: 'In Virtue',
        day: 'Day 1',
        date: '1/29/2026',
        venue: 'Boleros',
        start: '12:00',
        end: '13:00',
        type: 'Meet and Greet',
      ),
      event(
        band: 'Solo',
        day: 'Day 1',
        date: '1/29/2026',
        venue: 'Boleros',
        start: '12:30',
        end: '13:30',
        type: 'Meet and Greet',
      ),
    ], workspace);

    expect(layout.eventCount, 3);
    expect(layout.pages.single.events.length, 2);
    final merged = layout.pages.single.events.firstWhere(
      (event) => event.sources.length > 1,
    );
    expect(merged.bandNames, ['Illdisposed', 'In Virtue']);
    expect(merged.laneCount, 2);
    final overlapping = layout.pages.single.events.firstWhere(
      (event) =>
          event.sources.length == 1 && event.sources.first.band == 'Solo',
    );
    expect(overlapping.laneIndex, 1);
    expect(overlapping.laneCount, 2);

    final html = utf8.decode(
      HtmlExporter.build(
        layout: layout,
        festivalName: 'Test Fest',
        labeling: EventTypeLabeling.forSelection(['Meet and Greet']),
      ),
    );
    expect(html, contains('Illdisposed'));
    expect(html, contains('In Virtue'));
    expect(html, contains('Solo'));
    expect(html, contains('dense'));
  });

  test('labels clinics/meet-greets/unofficial only when types are mixed', () {
    final clinicsOnly = EventTypeLabeling.forSelection(['Clinic']);
    expect(clinicsOnly.pageHeaderLabel, 'CLINICS');
    expect(clinicsOnly.labelEventsIndividually, isFalse);
    expect(clinicsOnly.eventLabel('Clinic'), isNull);

    final meetOnly = EventTypeLabeling.forSelection(['Meet and Greet']);
    expect(meetOnly.pageHeaderLabel, 'MEET & GREETS');
    expect(meetOnly.eventLabel('Meet and Greet'), isNull);

    final unofficialOnly = EventTypeLabeling.forSelection(['Unofficial Event']);
    expect(unofficialOnly.pageHeaderLabel, 'UNOFFICIAL EVENTS');

    expect(EventTypeLabeling.fileSlugForSelection(['Show']), 'shows');
    expect(
      EventTypeLabeling.fileSlugForSelection(['Meet and Greet']),
      'meet-and-greets',
    );
    expect(EventTypeLabeling.fileSlugForSelection(['Clinic']), 'clinics');
    expect(
      EventTypeLabeling.fileSlugForSelection(['Show', 'Clinic']),
      isNull,
    );
    final showsOnly = EventTypeLabeling.forSelection(['Show']);
    expect(showsOnly.pageHeaderLabel, isNull);
    expect(showsOnly.eventLabel('Show'), isNull);
    expect(showsOnly.eventLabel('Special Event'), isNull);

    final mixed = EventTypeLabeling.forSelection(['Show', 'Clinic']);
    expect(mixed.pageHeaderLabel, isNull);
    expect(mixed.labelEventsIndividually, isTrue);
    expect(mixed.eventLabel('Clinic'), 'CLINIC');
    expect(mixed.eventLabel('Meet and Greet'), 'MEET & GREET');
    expect(mixed.eventLabel('Unofficial Event'), 'UNOFFICIAL');
    expect(mixed.eventLabel('Show'), isNull);
    expect(mixed.eventLabel('Special Event'), isNull);
  });

  test('html includes page type header for clinic-only exports', () {
    final layout = RunningOrderLayout.build([
      event(
        band: 'Teacher',
        day: 'Day 1',
        date: '1/29/2026',
        venue: 'Theater',
        start: '12:00',
        end: '13:00',
        type: 'Clinic',
      ),
    ], workspace);
    final labeling = EventTypeLabeling.forSelection(['Clinic']);
    final html = utf8.decode(
      HtmlExporter.build(
        layout: layout,
        festivalName: 'Test Fest',
        labeling: labeling,
      ),
    );
    expect(html, contains('CLINICS'));
    expect(html, contains('class="type-label"'));
    expect(html, isNot(contains('<em class="event-type">')));
  });

  test('html labels clinic events when mixed with shows', () {
    final layout = RunningOrderLayout.build([
      event(
        band: 'Band',
        day: 'Day 1',
        date: '1/29/2026',
        venue: 'Theater',
        start: '17:30',
        end: '18:15',
      ),
      event(
        band: 'Teacher',
        day: 'Day 1',
        date: '1/29/2026',
        venue: 'Theater',
        start: '12:00',
        end: '13:00',
        type: 'Clinic',
      ),
    ], workspace);
    final labeling = EventTypeLabeling.forSelection(['Show', 'Clinic']);
    final html = utf8.decode(
      HtmlExporter.build(
        layout: layout,
        festivalName: 'Test Fest',
        labeling: labeling,
      ),
    );
    expect(html, contains('<em class="event-type">CLINIC</em>'));
    expect(html, isNot(contains('class="type-label"')));
  });

  test('pdf keeps band names on long days with short slots', () async {
    const longDay = FestivalWorkspace(
      days: ['Day 3'],
      dates: ['1/16/2026', '1/17/2026'],
      venues: [
        'Pool',
        'Theater',
        'Rink',
        'Lounge',
        'Sports Bar',
        'Ale & Anchor Pub',
      ],
    );
    final layout = RunningOrderLayout.build([
      event(
        band: 'Hiraes',
        day: 'Day 3',
        date: '1/16/2026',
        venue: 'Pool',
        start: '10:00',
        end: '10:45',
      ),
      event(
        band: 'Harakiri for the Sky',
        day: 'Day 3',
        date: '1/16/2026',
        venue: 'Theater',
        start: '10:45',
        end: '11:30',
      ),
      event(
        band: 'Anthrax',
        day: 'Day 3',
        date: '1/16/2026',
        venue: 'Pool',
        start: '21:45',
        end: '22:45',
      ),
      event(
        band: 'Late Act',
        day: 'Day 3',
        date: '1/16/2026',
        venue: 'Rink',
        start: '05:00',
        end: '05:45',
      ),
    ], longDay);

    final bytes = await PdfExporter.build(
      layout: layout,
      festivalName: 'Test Fest',
    );
    await Directory('/tmp/70k-ro').create(recursive: true);
    final file = File('/tmp/70k-ro/long-day.pdf');
    await file.writeAsBytes(bytes);
    final extracted = await Process.run('pdftotext', ['-layout', file.path, '-']);
    expect(extracted.exitCode, 0);
    final text = extracted.stdout.toString();
    expect(text, contains('HIRAES'));
    expect(text, contains('HARAKIRI'));
    expect(text, contains('ANTHRAX'));
    expect(text, contains('LATE ACT'));
  });

  test('pdf short interstitial does not omit the following set', () async {
    // Repro: 5-minute raffle between shows used to grow over the next block.
    const workspace = FestivalWorkspace(
      days: ['Saturday'],
      dates: ['6/13/2026', '6/14/2026'],
      venues: ['Stage 1', 'Stage 2'],
    );
    final layout = RunningOrderLayout.build([
      event(
        band: 'Graveshadow',
        day: 'Saturday',
        date: '6/13/2026',
        venue: 'Stage 1',
        start: '20:05',
        end: '20:30',
      ),
      event(
        band: 'Raffle Give Away',
        day: 'Saturday',
        date: '6/13/2026',
        venue: 'Stage 1',
        start: '20:35',
        end: '20:40',
      ),
      event(
        band: 'Holy Divers',
        day: 'Saturday',
        date: '6/13/2026',
        venue: 'Stage 1',
        start: '20:45',
        end: '21:45',
      ),
    ], workspace);

    final bytes = await PdfExporter.build(
      layout: layout,
      festivalName: 'Redwood',
    );
    await Directory('/tmp/70k-ro').create(recursive: true);
    final file = File('/tmp/70k-ro/short-interstitial.pdf');
    await file.writeAsBytes(bytes);
    final extracted = await Process.run('pdftotext', [
      '-layout',
      file.path,
      '-',
    ]);
    expect(extracted.exitCode, 0);
    final text = extracted.stdout.toString();
    expect(text, contains('RAFFLE GIVE AWAY'));
    expect(text, contains('HOLY DIVERS'));
    expect(text, contains('GRAVESHADOW'));
    // Name is listed before time so short-slot clipping keeps the title.
    final raffleAt = text.indexOf('RAFFLE GIVE AWAY');
    final raffleTimeAt = text.indexOf('20.35');
    expect(raffleAt, greaterThanOrEqualTo(0));
    expect(raffleTimeAt, greaterThanOrEqualTo(0));
    expect(raffleAt, lessThan(raffleTimeAt));
  });

  test('html expands schedule height for crowded long days', () {
    const shortDayWorkspace = FestivalWorkspace(
      days: ['Day 1'],
      dates: ['1/14/2026', '1/15/2026'],
      venues: ['Theater'],
    );
    final shortLayout = RunningOrderLayout.build([
      event(
        band: 'Band',
        day: 'Day 1',
        date: '1/14/2026',
        venue: 'Theater',
        start: '18:00',
        end: '19:00',
      ),
    ], shortDayWorkspace);
    final shortHtml = utf8.decode(
      HtmlExporter.build(layout: shortLayout, festivalName: 'Test Fest'),
    );
    expect(shortHtml, contains('height:500px'));

    const crowdedWorkspace = FestivalWorkspace(
      days: ['Day 3'],
      dates: ['1/16/2026', '1/17/2026'],
      venues: [
        'Pool',
        'Theater',
        'Rink',
        'Lounge',
        'Sports Bar',
        'Ale & Anchor Pub',
      ],
    );
    final crowdedLayout = RunningOrderLayout.build([
      for (var i = 0; i < 8; i++)
        event(
          band: 'Act $i',
          day: 'Day 3',
          date: '1/16/2026',
          venue: crowdedWorkspace.venues[i % crowdedWorkspace.venues.length],
          start: '${(10 + i).toString().padLeft(2, '0')}:00',
          end: '${(10 + i).toString().padLeft(2, '0')}:45',
        ),
      event(
        band: 'Late',
        day: 'Day 3',
        date: '1/16/2026',
        venue: 'Pool',
        start: '05:00',
        end: '05:45',
      ),
    ], crowdedWorkspace);
    final crowdedHtml = utf8.decode(
      HtmlExporter.build(layout: crowdedLayout, festivalName: 'Test Fest'),
    );
    final match = RegExp(r'height:(\d+)px').firstMatch(crowdedHtml);
    expect(match, isNotNull);
    expect(int.parse(match!.group(1)!), greaterThan(500));
  });

  test('builds self-contained HTML and a valid PDF', () async {
    final layout = RunningOrderLayout.build([
      event(
        band: 'A & B',
        day: 'Day 1',
        date: '1/29/2026',
        venue: 'Theater',
        start: '17:30',
        end: '18:15',
      ),
    ], workspace);

    final html = utf8.decode(
      HtmlExporter.build(layout: layout, festivalName: 'Test Fest'),
    );
    expect(html, startsWith('<!doctype html>'));
    expect(html, contains('A &amp; B'));
    expect(html, contains('<body class="color">'));
    expect(html, contains('@page { size: A4 landscape'));

    final monochromeHtml = utf8.decode(
      HtmlExporter.build(
        layout: layout,
        festivalName: 'Test Fest',
        useColor: false,
      ),
    );
    expect(monochromeHtml, contains('<body class="monochrome">'));

    final monochromePdf = await PdfExporter.build(
      layout: layout,
      festivalName: 'Test Fest',
    );
    final colorPdf = await PdfExporter.build(
      layout: layout,
      festivalName: 'Test Fest',
      useColor: true,
    );
    expect(ascii.decode(monochromePdf.take(4).toList()), '%PDF');
    expect(ascii.decode(colorPdf.take(4).toList()), '%PDF');
  });
}
