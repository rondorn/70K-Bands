/// Venue order for QR location codes — keep in sync with 70K app config and
/// [build_70k_schedule_poster_pdf.py].
const scheduleQrVenueNames = <String>[
  'Pool',
  'Lounge',
  'Theater',
  'Rink',
  'Schooner Pub',
  'Arcade',
  'Sports Bar',
  'Viking Crown',
  'Boleros Lounge',
  'Solarium',
  'Ale And Anchor Pub',
  'Ale & Anchor Pub',
  'Bull And Bear Pub',
  'Bull & Bear Pub',
];

/// Event type order for QR digit codes — keep in sync with iOS + Android.
const scheduleQrEventTypeOrder = <String>[
  'Show',
  'Meet and Greet',
  'Unofficial Event',
  'Special Event',
  'Clinic',
  'Cruiser Organized',
];

const scheduleQrHeader =
    'Band,Location,Date,Day,Start Time,End Time,Type,Notes';

const scheduleQrMaxBytesPerBinaryQr = 2953;

const scheduleQrTypeFull = 0;
const scheduleQrTypeChunk1 = 1;
const scheduleQrTypeChunk2 = 2;

const scheduleQrTargetPx = 720;
const scheduleQrGuideTargetPx = 200;
const scheduleQrQuietZoneModules = 4;
const scheduleQrMinPixelsPerModule = 6;

const scheduleQrDropboxPrefix = 'https://www.dropbox.com/';
const scheduleQrDropboxPlaceholder = '!DB!';

const scheduleQrUnofficialTypes = {'Unofficial Event', 'Cruiser Organized'};
