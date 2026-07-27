package com.Bands70k;

import org.junit.Test;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

public class BandInfoLinkTest {

    @Test
    public void isNonEmptyWebLink_rejectsBlankValues() {
        assertFalse(BandInfo.isNonEmptyWebLink(null));
        assertFalse(BandInfo.isNonEmptyWebLink(""));
        assertFalse(BandInfo.isNonEmptyWebLink("   "));
    }

    @Test
    public void isNonEmptyWebLink_acceptsRealUrls() {
        assertTrue(BandInfo.isNonEmptyWebLink("https://example.com"));
        assertTrue(BandInfo.isNonEmptyWebLink(" www.youtube.com/watch?v=abc "));
        assertTrue(BandInfo.isNonEmptyWebLink("https://musicbrainz.org/artist/abc"));
    }
}
